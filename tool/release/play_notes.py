#!/usr/bin/env python3
"""Writes the Google Play release notes ("What's new") of a version (ADR-0067).

The notes are the version's user notes in app/assets/whats_new.json (ADR-0041),
the same lines the app shows after an update: German as de-DE, English as
en-US (the languages of the store listing in docs/store/play/), one bullet
per line, cut to Play's 500 characters per language. A version without notes
(a patch release) gets a short generic text, because Play shows the field to
users.

    tool/release/play_notes.py <version> <output-dir>

writes <output-dir>/whatsnew-de-DE and <output-dir>/whatsnew-en-US, the
layout of the upload action's `whatsNewDirectory`.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WHATS_NEW = ROOT / "app" / "assets" / "whats_new.json"

# Play's limit per language.
LIMIT = 500

# whats_new.json language → Play locale.
LOCALES = {"de": "de-DE", "en": "en-US"}

FALLBACK = {
    "de": "Fehlerbehebungen und kleine Verbesserungen.",
    "en": "Bug fixes and small improvements.",
}


class NotesError(Exception):
    pass


def notes(lines: list[str], language: str) -> str:
    """The lines as bullets, whole lines only, within LIMIT characters."""
    if not lines:
        return FALLBACK[language]
    out: list[str] = []
    for line in lines:
        bullet = f"• {line.strip()}"
        candidate = "\n".join([*out, bullet])
        if len(candidate) > LIMIT:
            break
        out.append(bullet)
    if not out:
        # A single line longer than the limit: cut it at a word.
        cut = f"• {lines[0].strip()}"[: LIMIT - 1]
        out.append(cut[: cut.rfind(" ")] + "…")
    return "\n".join(out)


def play_notes(whats_new: dict, version: str) -> dict[str, str]:
    """Play locale → release notes of the version."""
    entry = whats_new.get(version)
    if entry is None:
        raise NotesError(f"whats_new.json has no entry for {version}")
    return {locale: notes(entry.get(lang, []), lang) for lang, locale in LOCALES.items()}


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    version, out_dir = args[0].removeprefix("v"), Path(args[1])
    try:
        result = play_notes(json.loads(WHATS_NEW.read_text(encoding="utf-8")), version)
    except NotesError as error:
        print(f"play_notes: {error}", file=sys.stderr)
        return 1
    out_dir.mkdir(parents=True, exist_ok=True)
    for locale, text in result.items():
        (out_dir / f"whatsnew-{locale}").write_text(text, encoding="utf-8")
        print(f"--- {locale} ({len(text)} characters)\n{text}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
