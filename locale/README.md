# Languages

Russian is the game's source language: every text is written in Russian in
`scripts/`, and that Russian text is its own translation key. Every other
language is one gettext file here, `<code>.po` (`en.po`, `de.po`). The `Lang`
autoload (`scripts/lang.gd`) finds and loads every `.po` in this folder at
start, and the main menu's language button lists them.

## Adding a language

1. Copy `en.po` to `<code>.po`, where `<code>` is the language's ISO code
   (`fr`, `es`, `pl`...).
2. In its header set `"Language: <code>\n"`.
3. Set `@language` to the language's name in itself (`Français`), and
   `@lowercase` to `no` if nouns keep their capital letter inside a sentence
   (as in German), `yes` otherwise.
4. Replace every `msgstr` with the translation. Keep each `%d`, `%s`, `%.0f`,
   `%02d` and `%%` in the same order as in the `msgid`; `[b]...[/b]` is
   formatting and stays too.
5. Run `tests/run_tests.ps1 -Only locale`: it fails on any missing text, a
   lost placeholder, or a stale entry.

Poedit or any gettext editor can open the files. Card titles have about 10
characters of room; longer single words get squeezed to a small font.

## Adding or changing a text in the code

Write the Russian text in the code, and pass it through `tr()` where it is
shown (`TranslationServer.translate()` in a static function). Data tables
(names, descriptions) keep the Russian and are translated where they are
displayed. Then add the new text to every `.po`; the locale test lists what is
missing. A changed Russian text is a new key: the old entry shows up as stale.
Put a whole sentence in one text with placeholders rather than gluing pieces
together, since word order differs between languages.

The testbed's debug panel (`scripts/debug_panel.gd`) is a developer's tool and
stays in Russian.
