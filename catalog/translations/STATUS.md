# Translation status

100 lessons (`selection.txt`) adapted from English into 29 languages. All of them pass `python3 build.py check <lang>` (structure identical to English, no empty string, no em dash, length limits, glossary file complete) and `python3 build.py merge <lang>` produces `build/<lang>/<slug>.json` (git-ignored, about 34 MB for the 2900 files).

Languages (folder = code): fr it es de pt (Brazilian, stored as `pt-BR`) pt-PT tr hr nb sv da pl ro nl el hu bg cs ru sl sk sr (Latin script) ar he fi et lt lv ja.

Files: `BRIEF.md` (rules), `TASK.md` / `GLOSSARY_TASK.md` (how one batch / one glossary is done), `<lang>/meta.json` (titles, artists, museums, movements: the glossary), `<lang>/lessons/<slug>.json`, `build.py` (extract / check / merge).

Verified: quiz answers, true/false values and zoom coordinates are identical to the English in all 2900 merged lessons.

## Supabase (project "Artura", dsbhaddvzpswkjzqskhv): NOTHING LOADED YET
1. Apply `supabase/migrations/20261122120000_translations.sql` (never applied: the approval prompt timed out). Six `*_translations` tables + two loader functions in schema `private`; English tables untouched; language codes are free-form (BCP 47).
2. Load: 34 MB is far too much to paste through the SQL tool. Plan: a temporary Edge Function (service role, one-time token) that receives one merged lesson per request and calls `private.upsert_lesson_translation(slug, lang, json)`; call it from the container with curl; delete it afterwards. Movements: `private.upsert_movement_translations(lang, <movements part of meta.json>)`. DB language code = folder name, except `pt` -> `pt-BR` (`build.DB_CODE`).
3. The iOS app still reads only the English tables.

## Known loose ends
- Source inconsistencies in the English lessons, reported by translators and translated as written (Marc "two details" for three spots, Creation of Adam "three places" for four, Las Meninas nine vs eleven figures, Jonghelinck spelling, Bosch "strawberry" (madroño), Seurat/Gauguin "three kinds"/"two directions" line counts, Cezanne "five versions"). Worth fixing in the English first, then re-propagating.
- Quotation marks: pt-PT normalised to « »; Latvian lessons mix „ “ and “ ” (not normalised).
- Titles chosen by translators from memory (not looked up) in every glossary: a native review of `<lang>/meta.json` is advisable before release.
