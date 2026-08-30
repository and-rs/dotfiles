import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import { MAX_FETCH_BYTES, MAX_REDIRECTS, USER_AGENT } from "./types.ts";

function isPrivateIPv4(address: string): boolean {
  const parts = address.split(".").map((part) => Number.parseInt(part, 10));
  if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return true;
  const [a, b] = parts;
  return a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || a >= 224;
}

function isPrivateIPv6(address: string): boolean {
  const normalized = address.toLowerCase();
  if (normalized.startsWith("::ffff:")) return isPrivateIPv4(normalized.slice(7));
  return normalized === "::" || normalized === "::1" || normalized.startsWith("fc") || normalized.startsWith("fd") || normalized.startsWith("fe80:");
}

function isPrivateAddress(address: string): boolean {
  const family = isIP(address);
  if (family === 4) return isPrivateIPv4(address);
  if (family === 6) return isPrivateIPv6(address);
  return true;
}

export async function assertPublicHttpUrl(urlText: string): Promise<void> {
  const url = new URL(urlText);
  if (url.protocol !== "http:" && url.protocol !== "https:") throw new Error(`Unsupported URL protocol: ${url.protocol}. Use http or https.`);
  const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (hostname === "localhost" || hostname.endsWith(".localhost")) throw new Error(`Blocked local URL host: ${url.hostname}`);
  if (isIP(hostname)) {
    if (isPrivateAddress(hostname)) throw new Error(`Blocked private URL host: ${url.hostname}`);
    return;
  }
  const addresses = await lookup(hostname, { all: true, verbatim: true });
  if (addresses.length === 0 || addresses.some((entry) => isPrivateAddress(entry.address))) {
    throw new Error(`Blocked URL host resolving to private address: ${url.hostname}`);
  }
}

export async function fetchPublicUrl(url: string, init: RequestInit): Promise<Response> {
  let currentUrl = url;
  for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount++) {
    await assertPublicHttpUrl(currentUrl);
    const response = await fetch(currentUrl, { ...init, redirect: "manual" });
    if (![301, 302, 303, 307, 308].includes(response.status)) return response;
    const location = response.headers.get("location");
    if (!location) return response;
    currentUrl = new URL(location, currentUrl).toString();
  }
  throw new Error(`Too many redirects fetching URL: ${url}`);
}

export async function readResponseTextCapped(response: Response, maxBytes: number = MAX_FETCH_BYTES): Promise<{ text: string; truncated: boolean }> {
  if (!response.body) return { text: "", truncated: false };
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let text = "";
  let bytesRead = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    const remaining = maxBytes - bytesRead;
    if (remaining <= 0) {
      await reader.cancel();
      return { text: `${text}${decoder.decode()}`, truncated: true };
    }
    if (value.byteLength > remaining) {
      text += decoder.decode(value.slice(0, remaining), { stream: true });
      await reader.cancel();
      return { text: `${text}${decoder.decode()}`, truncated: true };
    }
    bytesRead += value.byteLength;
    text += decoder.decode(value, { stream: true });
  }
  return { text: `${text}${decoder.decode()}`, truncated: false };
}

export function defaultFetchHeaders(): HeadersInit {
  return {
    Accept: "text/html,application/xhtml+xml,application/json,text/plain;q=0.9,*/*;q=0.8",
    "User-Agent": USER_AGENT,
  };
}
