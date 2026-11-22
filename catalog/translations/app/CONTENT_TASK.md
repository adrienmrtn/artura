# Translating the content bundled in the app (onboarding and widget)

You are given a target language (name and folder code `<lang>`). You write as a native author of popular art books in that language.

1. Work in `/home/user/artura/catalog/translations/`. Read `BRIEF.md` completely (same rules as the catalog lessons: natural adaptation, not word for word; register, quotation marks, no em dash, metric, etc.), then `<lang>/meta.json`, the glossary already used for the catalog in your language.
2. Read `app/source/content.json`: 6 movements and 8 artworks with their lessons, quizzes and true/false facts. These are shown in the onboarding, the widget and as the first lessons. Write `app/<lang>/content.json` with exactly the same JSON structure (same keys, same number of items, same order), every string adapted.
3. Names must match the rest of the app: when an artwork, artist, museum or movement of `content.json` also exists in `<lang>/meta.json` (for example The Starry Night is `gogh-the-starry-night` there, Mona Lisa is `vinci-mona-lisa`, the movement "Post-Impressionism" is a movement there), use exactly the glossary's wording. For the others, use the established name in your language.
4. `yearLabel` is a date label ("1889", "c. 1503–1519"): adapt only the wording ("c." and the like), keep the digits. Colour names in `swatches` should be short (1 to 3 words).
5. Write it yourself with care, no machine-translation shortcut, no script producing text, no delegation.
6. Run `python3 app/app.py check <lang>` and fix every problem reported under `content.json` until there is none (ignore the lines about `ui.json`, another agent handles them).
7. Reread one long lesson as a native reader would and fix anything that sounds translated. Do not commit or push. Write only that one file.

Final report, 4 lines at most: check result, names where you departed from the glossary, factual doubts about the English.
