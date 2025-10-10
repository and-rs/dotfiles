from __future__ import annotations

base: dict[str, str] = {
    "alt.i": "C-l",
    "alt.d": "C-d",
    "alt.b": "C-b",
    "alt.a": "C-a",
    "alt.z": "C-z",
    "alt.f": "C-f",
    "alt.c": "C-c",
    "alt.v": "C-v",
    "alt.w": "C-w",
    "alt.t": "C-t",
    "alt.r": "C-r",
    "control.u": "macro(S-home delete)",
    "control.k": "macro(S-end delete)",
    "control.n": "down",
    "control.p": "up",
    "control.f": "right",
    "control.b": "left",
    "control.a": "home",
    "control.e": "end",
    "control.d": "delete",
    "meta.backspace": "C-backspace",
    "meta.f": "C-right",
    "meta.b": "C-left",
    "alt.e": "C-e",
    "alt.p": "C-p",
}

apps: list[str] = [
    "zen-beta",
    "brave-browser",
    "google-chrome",
    "obsidian",
    "spotify",
    "vesktop",
]

overrides: dict[str, dict[str, str | None]] = {
    "obsidian": {"control.d": None, "control.u": None},
    # "google-chrome": {"alt.p": None},
}

additions: dict[str, dict[str, str]] = {
    # "obsidian": {"control.h": "backspace"},
}


def sort_keys(m: dict[str, str]) -> list[str]:
    return sorted(m.keys(), key=lambda k: (k.split(".")[0], k))


def render_section(name: str, m: dict[str, str]) -> str:
    lines: list[str] = [f"[{name}]"]
    for k in sort_keys(m):
        lines.append(f"{k} = {m[k]}")
    return "\n".join(lines) + "\n"


def build() -> str:
    parts: list[str] = []
    for app in apps:
        m = {**base, **additions.get(app, {})}
        for k, v in (overrides.get(app, {}) or {}).items():
            if v is None:
                _ = m.pop(k, None)
            else:
                m[k] = v
        parts.append(render_section(app, m))
    return "\n".join(parts)


if __name__ == "__main__":
    print(build(), end="")
