import { assertPublicHttpUrl, defaultFetchHeaders, fetchPublicUrl, readResponseTextCapped } from "./network.ts";
import { normalizeWhitespaceText, parseHtmlDocument } from "./html.ts";
import { MAX_FETCH_BYTES, type FetchMode } from "./types.ts";
import { truncate } from "./shared.ts";

export async function fetchUrlContent(url: string, mode: FetchMode, maxCharacters: number, timeoutMs: number, signal?: AbortSignal): Promise<{ text: string; details: { url: string; finalUrl: string; title: string | null; contentType: string; status: number; mode: FetchMode; truncated: boolean } }> {
  const timeoutSignal = AbortSignal.timeout(timeoutMs);
  const combinedSignal = signal ? AbortSignal.any([signal, timeoutSignal]) : timeoutSignal;
  const response = await fetchPublicUrl(url, { headers: defaultFetchHeaders(), signal: combinedSignal });
  if (!response.ok) throw new Error(`Fetch failed: ${response.status} ${response.statusText}`);
  await assertPublicHttpUrl(response.url);
  const finalUrl = response.url;
  const contentType = response.headers.get("content-type")?.toLowerCase() || "";
  const cappedBody = await readResponseTextCapped(response, MAX_FETCH_BYTES);
  const body = cappedBody.text;
  let title: string | null = null;
  let extracted = "";
  if (contentType.includes("text/html") || contentType.includes("application/xhtml+xml")) {
    const parsed = parseHtmlDocument(body, finalUrl);
    title = parsed.title;
    extracted = mode === "html" ? parsed.html : mode === "text" ? parsed.text : parsed.markdown || parsed.text;
  } else if (contentType.includes("application/json")) {
    const parsed = JSON.parse(body) as unknown;
    extracted = JSON.stringify(parsed, null, 2);
  } else if (contentType.startsWith("text/") || contentType.includes("application/xml") || contentType.includes("application/javascript")) {
    extracted = body;
  } else {
    throw new Error(`Unsupported content type: ${contentType || "unknown"}`);
  }
  const cleaned = normalizeWhitespaceText(extracted);
  const truncated = truncate(cleaned, maxCharacters);
  const prefix = [title ? `Title: ${title}` : null, `URL: ${finalUrl}`, ""].filter(Boolean).join("\n");
  return { text: `${prefix}${truncated.text}`.trim(), details: { url, finalUrl, title, contentType, status: response.status, mode, truncated: truncated.truncated || cappedBody.truncated } };
}
