import { FETCH_MODES, SEARCH_TYPES, type FetchMode, type SearchType } from "./types.ts";

export function isSearchType(value: string): value is SearchType {
  return SEARCH_TYPES.includes(value as SearchType);
}

export function isFetchMode(value: string): value is FetchMode {
  return FETCH_MODES.includes(value as FetchMode);
}

export function truncate(value: string, maxCharacters: number): { text: string; truncated: boolean } {
  if (value.length <= maxCharacters) return { text: value, truncated: false };
  return { text: `${value.slice(0, Math.max(0, maxCharacters - 16)).trimEnd()}\n\n[truncated]`, truncated: true };
}
