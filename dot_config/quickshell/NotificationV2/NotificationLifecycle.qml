pragma Singleton
import Quickshell

Singleton {
	id: root

	function dismiss(notification: var): void {
		if (notification)
			notification.dismiss();
	}
	function expire(notification: var): void {
		if (notification)
			notification.expire();
	}
	function invoke(notification: var, actionIndex: int): void {
		if (!notification || !notification.actions || actionIndex < 0 || actionIndex >= notification.actions.length)
			return;
		notification.actions[actionIndex].invoke();
	}
	function sendInlineReply(notification: var, text: string): void {
		const reply = String(text || "").trim();
		if (!reply || !notification || !notification.hasInlineReply)
			return;
		notification.sendInlineReply(reply);
	}
}
