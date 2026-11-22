# Translation status

100 lessons (`selection.txt`) adapted from English into 29 languages. All of them pass `python3 build.py check <lang>` (structure identical to English, no empty string, no em dash, length limits, glossary file complete) and `python3 build.py merge <lang>` produces `build/<lang>/<slug>.json` (git-ignored, about 34 MB for the 2900 files).

Languages (folder = code): fr it es de pt (Brazilian, stored as `pt-BR`) pt-PT tr hr nb sv da pl ro nl el hu bg cs ru sl sk sr (Latin script) ar he fi et lt lv ja.

Files: `BRIEF.md` (rules), `TASK.md` / `GLOSSARY_TASK.md` (how one batch / one glossary is done), `<lang>/meta.json` (titles, artists, museums, movements: the glossary), `<lang>/lessons/<slug>.json`, `build.py` (extract / check / merge).

Verified: quiz answers, true/false values and zoom coordinates are identical to the English in all 2900 merged lessons.

## The app itself (done)
- Interface: every visible string goes through `L("English")` (`Artura/Core/Localization.swift`), 550 keys, translated in `app/<lang>/ui.json`, built into `Artura/Resources/<code>.lproj/Localizable.strings` (+ a copy in `ArturaWidget/`). The app follows the iPhone language, or Settings > Artura > Language.
- Bundled content (onboarding, widget, first lessons): `app/<lang>/content.json` -> `Artura/Resources/content.<code>.json`.
- Catalog: the 100 translated lessons are bundled (`Artura/Resources/lessons.<code>.json`, about 1 MB per language). In a language other than English the app shows only those 100 artworks, with translated titles, movements, lessons, quizzes and true/false (`TranslatedCatalog` in `Models.swift`). Works offline, does not need Supabase.
- Rebuild after any change: `python3 catalog/translations/app/app.py extract`, translate new keys, `check`, `build`.
- Not compiled here (no Xcode on Linux): only a syntax check was run. Build in Xcode before release.

## Supabase (project "Artura", dsbhaddvzpswkjzqskhv): NOTHING LOADED YET
1. Apply `supabase/migrations/20261122120000_translations.sql` (never applied: the approval prompt timed out). Six `*_translations` tables + two loader functions in schema `private`; English tables untouched; language codes are free-form (BCP 47).
2. Load: 34 MB is far too much to paste through the SQL tool. Plan: a temporary Edge Function (service role, one-time token) that receives one merged lesson per request and calls `private.upsert_lesson_translation(slug, lang, json)`; call it from the container with curl; delete it afterwards. Movements: `private.upsert_movement_translations(lang, <movements part of meta.json>)`. DB language code = folder name, except `pt` -> `pt-BR` (`build.DB_CODE`).
3. The iOS app does not read these tables: it uses the bundled translations. The tables are optional (for later updates without an app release).

## Known loose ends
- Source inconsistencies in the English lessons, reported by translators and translated as written (Marc "two details" for three spots, Creation of Adam "three places" for four, Las Meninas nine vs eleven figures, Jonghelinck spelling, Bosch "strawberry" (madroño), Seurat/Gauguin "three kinds"/"two directions" line counts, Cezanne "five versions"). Worth fixing in the English first, then re-propagating.
- Quotation marks: pt-PT normalised to « »; Latvian lessons mix „ “ and “ ” (not normalised).
- Titles chosen by translators from memory (not looked up) in every glossary: a native review of `<lang>/meta.json` is advisable before release.
