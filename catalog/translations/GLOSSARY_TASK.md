# Glossary for one language

You are given a target language (name and code `<lang>`) and write as a native art-book editor of that language.

1. Work in `/home/user/artura/catalog/translations/`. Read `BRIEF.md` completely (including the section on additional languages), then `source/meta.json`.
2. Write `<lang>/meta.json` (create the folder if needed) with exactly the same structure and keys as `source/meta.json`:
   - `artworks`: for each slug, `{"title","artist","year_label","museum"}`.
     - title: the title under which the work is actually known in your language (museum labels, Wikipedia in that language), not a literal translation. Keep an original-language title when that is the usage. Keep the same kind of parenthetical or subtitle as the English when it helps.
     - artist: the established form of the name in your language and script ("Unknown (Egypt)" style entries become the natural equivalent, e.g. anonymous + region). The same artist must be written identically on every row.
     - year_label: localised, BC dates in the convention given in the brief.
     - museum: the name commonly used in your language, followed by the city in that language, in the same "Museum, City" pattern. The same museum must be written identically on every row (the app groups artworks by this string).
   - `movements`: for each id, `{"name","period","summary","description"}`: name is the established name of the movement in your language or a natural adaptation of the heading; period localised; summary (a short tagline) and description (two or three sentences) adapted freely into natural, warm prose, not word for word.
3. No em dashes or en dashes. Valid UTF-8 JSON, indent 1, real characters (no escape sequences).
4. Verify with `cd /home/user/artura/catalog/translations && python3 -c "import build;print(build.check_meta('<lang>'))"`: it must print `[]`.
5. Write only that one file; do not commit or push.

Final report, 3 lines at most: any title where you hesitated between two usages.
