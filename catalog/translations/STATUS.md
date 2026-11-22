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

## Supabase (project "Artura"): LOADED
- Migration `supabase/migrations/20261122120000_translations.sql` applied. Six `*_translations` tables, language codes as in iOS (`fr`, `pt-BR`, `sr-Latn`...).
- Loaded on 2026-11-22: 29 languages x 100 lessons (2900 lessons, 49039 blocks, 15892 quiz questions, 8700 facts, 841 movement rows); quiz answers and block types checked against the English.
- Loaded through a temporary Edge Function `import-translations`, now replaced by a disabled version (returns 410; can be deleted in the dashboard). To reload: redeploy a loader (see `app/load_supabase.py`) and call it.
- The app reads these tables (`RemoteCatalog.translations`, `translatedLesson`): titles, movements and true/false come from Supabase when online, the bundled files are the offline fallback, and a lesson translated in the database but not bundled is downloaded when opened.

## Language choice in the app
- Welcome screen: native menu (globe) to switch language. Second screen of the onboarding: "Which language?", full list.
- The switch is immediate (`AppLanguage.set`) and kept for the next launches (it writes `AppleLanguages`). The widget follows the iPhone / Settings language (no app group to share the choice).

## Known loose ends
- Source inconsistencies in the English lessons, reported by translators and translated as written (Marc "two details" for three spots, Creation of Adam "three places" for four, Las Meninas nine vs eleven figures, Jonghelinck spelling, Bosch "strawberry" (madroño), Seurat/Gauguin "three kinds"/"two directions" line counts, Cezanne "five versions"). Worth fixing in the English first, then re-propagating.
- Quotation marks: pt-PT normalised to « »; Latvian lessons mix „ “ and “ ” (not normalised).
- Titles chosen by translators from memory (not looked up) in every glossary: a native review of `<lang>/meta.json` is advisable before release.
