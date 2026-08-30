import { Readability } from "@mozilla/readability";
import { JSDOM } from "jsdom";
import TurndownService from "turndown";
import { gfm } from "turndown-plugin-gfm";

function normalizeWhitespace(value: string): string {
  return value.replace(/\r/g, "").replace(/\n{3,}/g, "\n\n").trim();
}

function buildTurndown(): TurndownService {
  const service = new TurndownService({ codeBlockStyle: "fenced", headingStyle: "atx", bulletListMarker: "-" });
  service.use(gfm);
  return service;
}

export function parseHtmlDocument(html: string, url: string): { title: string | null; markdown: string; text: string; html: string } {
  const dom = new JSDOM(html, { url });
  const title = dom.window.document.title.trim() || null;
  const article = new Readability(dom.window.document).parse();
  const sourceHtml = article?.content?.trim() || dom.window.document.body?.innerHTML?.trim() || html;
  const sourceText = article?.textContent?.trim() || dom.window.document.body?.textContent?.trim() || "";
  const turndown = buildTurndown();
  const markdown = normalizeWhitespace(turndown.turndown(sourceHtml || html));
  const text = normalizeWhitespace(sourceText);
  if (markdown.length >= 200) return { title, markdown, text, html: sourceHtml || html };
  const bodyHtml = dom.window.document.body?.innerHTML?.trim() || sourceHtml || html;
  const bodyText = normalizeWhitespace(dom.window.document.body?.textContent?.trim() || sourceText);
  const fallbackMarkdown = normalizeWhitespace(turndown.turndown(bodyHtml));
  return { title, markdown: fallbackMarkdown || markdown, text: bodyText || text, html: bodyHtml };
}

export function normalizeWhitespaceText(value: string): string {
  return normalizeWhitespace(value);
}
