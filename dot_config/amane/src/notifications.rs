mod body;
mod bus;
mod images;
#[cfg(test)]
mod tests;
mod view;

use std::{
    collections::VecDeque,
    sync::{Arc, OnceLock, mpsc::Sender},
    time::{Duration, Instant},
};

use amane::Service;
use zbus::names::OwnedUniqueName;

use crate::design;

pub use view::{bell, popup, sidebar, sidebar_backdrop};

const HISTORY_LIMIT: usize = 100;

struct Notice {
    owner: OwnedUniqueName,
    app: String,
    title: String,
    body: body::Body,
    actions: Vec<(String, String)>,
    reply: Option<String>,
    resident: bool,
    transient: bool,
    critical: bool,
    timeout: Option<Duration>,
    image: Arc<OnceLock<images::Preview>>,
}

#[derive(Clone)]
struct Entry {
    id: u32,
    notice: Arc<Notice>,
    live: bool,
    queued: bool,
    undo_until: Option<Instant>,
}

#[derive(Clone, Copy)]
struct Popup {
    id: u32,
    deadline: Option<Instant>,
}

enum Event {
    Schedule,
    Closed(u32, CloseReason),
    Action(u32, String),
    Reply(OwnedUniqueName, u32, String),
}

#[repr(u32)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum CloseReason {
    Expired = 1,
    Dismissed = 2,
    Requested = 3,
}

#[derive(Default)]
struct Notifications {
    entries: VecDeque<Entry>,
    next_id: u32,
    popup: Option<Popup>,
    monitor: Option<String>,
    reply_to: Option<u32>,
    events: Option<Sender<Event>>,
    running: bool,
}

impl Service for Notifications {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        if let Err(error) = bus::run() {
            eprintln!("notification server unavailable: {error}");
        }
    }
}

impl Notifications {
    fn entry(&self, id: u32) -> Option<&Entry> {
        self.entries.iter().find(|entry| entry.id == id)
    }

    fn send(&self, event: Event) {
        if let Some(events) = &self.events {
            let _ = events.send(event);
        }
    }

    fn submit(&mut self, replaces: u32, notice: Notice, now: Instant) -> u32 {
        if let Some(entry) = self
            .entries
            .iter_mut()
            .find(|entry| entry.id == replaces && entry.live && entry.notice.owner == notice.owner)
        {
            if self
                .popup
                .as_ref()
                .is_some_and(|popup| popup.id == replaces)
            {
                self.popup = Some(Popup {
                    id: replaces,
                    deadline: notice.timeout.map(|timeout| now + timeout),
                });
            }
            if notice.reply.is_none() && self.reply_to == Some(replaces) {
                self.reply_to = None;
            }
            entry.notice = Arc::new(notice);
            self.send(Event::Schedule);
            return replaces;
        }

        loop {
            self.next_id = self.next_id.wrapping_add(1).max(1);
            if self.entry(self.next_id).is_none() {
                break;
            }
        }
        let id = self.next_id;
        self.entries.push_front(Entry {
            id,
            notice: Arc::new(notice),
            live: true,
            queued: true,
            undo_until: None,
        });
        if self.entries.len() > HISTORY_LIMIT {
            let oldest = self.entries.back().unwrap().id;
            self.close(oldest, CloseReason::Dismissed, true, now);
        }
        self.advance(now);
        self.send(Event::Schedule);
        id
    }

    fn advance(&mut self, now: Instant) {
        if self.popup.is_none()
            && let Some(entry) = self.entries.iter_mut().rev().find(|entry| entry.queued)
        {
            entry.queued = false;
            self.popup = Some(Popup {
                id: entry.id,
                deadline: entry.notice.timeout.map(|timeout| now + timeout),
            });
        }
    }

    fn hide_popup(&mut self, id: u32, now: Instant) {
        if self.popup.as_ref().is_some_and(|popup| popup.id == id) {
            self.popup = None;
            self.advance(now);
            self.send(Event::Schedule);
        }
    }

    fn hide_popup_from_ui(&mut self, id: u32, now: Instant) {
        if !self.popup.is_some_and(|popup| popup.id == id) {
            return;
        }
        if self.entry(id).is_some_and(|entry| entry.notice.transient) {
            // A transient notice has no history entry to return to.
            self.close(id, CloseReason::Dismissed, false, now);
        } else {
            self.hide_popup(id, now);
        }
    }

    fn close(&mut self, id: u32, reason: CloseReason, remove: bool, now: Instant) {
        let Some(index) = self.entries.iter().position(|entry| entry.id == id) else {
            return;
        };
        let entry = &mut self.entries[index];
        let live = std::mem::take(&mut entry.live);
        entry.queued = false;
        if remove || entry.notice.transient {
            self.entries.remove(index);
        }
        if self.reply_to == Some(id) {
            self.reply_to = None;
        }
        self.hide_popup(id, now);
        if live {
            self.send(Event::Closed(id, reason));
        }
    }

    fn dismiss(&mut self, id: u32, now: Instant) {
        let Some(entry) = self.entries.iter_mut().find(|entry| entry.id == id) else {
            return;
        };
        entry.undo_until = Some(now + design::notifications::UNDO);
        entry.queued = false;
        if self.reply_to == Some(id) {
            self.reply_to = None;
        }
        self.hide_popup(id, now);
        self.send(Event::Schedule);
    }

    fn undo(&mut self, id: u32) {
        if let Some(entry) = self.entries.iter_mut().find(|entry| entry.id == id) {
            entry.undo_until = None;
            self.send(Event::Schedule);
        }
    }

    fn clear(&mut self) {
        self.popup = None;
        self.reply_to = None;
        while let Some(entry) = self.entries.pop_back() {
            if entry.live {
                self.send(Event::Closed(entry.id, CloseReason::Dismissed));
            }
        }
        self.send(Event::Schedule);
    }

    fn invoke(&mut self, id: u32, key: &str, now: Instant) {
        let Some(entry) = self.entry(id).filter(|entry| {
            entry.live
                && entry.undo_until.is_none()
                && entry.notice.actions.iter().any(|(action, _)| action == key)
        }) else {
            return;
        };
        let resident = entry.notice.resident;
        self.send(Event::Action(id, key.into()));
        if resident {
            self.hide_popup(id, now);
        } else {
            self.close(id, CloseReason::Dismissed, false, now);
        }
    }

    fn reply(&mut self, id: u32, text: &str, now: Instant) {
        let text = text.trim();
        if text.is_empty() || self.reply_to != Some(id) {
            return;
        }
        let Some(entry) = self
            .entry(id)
            .filter(|entry| entry.live && entry.notice.reply.is_some())
        else {
            return;
        };
        let resident = entry.notice.resident;
        self.send(Event::Reply(
            entry.notice.owner.clone(),
            id,
            text.chars().take(bus::BODY_LIMIT).collect(),
        ));
        self.reply_to = None;
        if resident {
            self.hide_popup(id, now);
        } else {
            self.close(id, CloseReason::Dismissed, false, now);
        }
    }

    fn deadline(&self) -> Option<Instant> {
        self.entries
            .iter()
            .filter_map(|entry| entry.undo_until)
            .chain(self.popup.as_ref().and_then(|popup| popup.deadline))
            .min()
    }

    fn tick(&mut self, now: Instant) {
        if let Some(popup) = &self.popup
            && popup.deadline.is_some_and(|deadline| now >= deadline)
        {
            self.close(popup.id, CloseReason::Expired, false, now);
        }
        while let Some(id) = self.entries.iter().find_map(|entry| {
            (entry.undo_until.is_some_and(|until| now >= until)).then_some(entry.id)
        }) {
            self.close(id, CloseReason::Dismissed, true, now);
        }
    }
}
