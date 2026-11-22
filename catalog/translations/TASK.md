# One translation batch

You are given a target language (name and code `<lang>`) and a batch number `<n>`. You write as a native author of popular art books in that language.

1. Work in `/home/user/artura/catalog/translations/`. Read `BRIEF.md` completely, then `<lang>/meta.json` (the glossary of titles, artists and museums you must follow).
2. Your batch is the 10 slugs listed in `batches/b<n>`. For each slug, read `source/<slug>.json` and write `<lang>/lessons/<slug>.json`: a natural adaptation in the target language (not a word-for-word translation) with exactly the same JSON structure.
3. Write them one at a time, each by you, with care. Do not produce text with a script or any machine-translation shortcut, and do not delegate to other agents.
4. When all 10 are written, run `python3 build.py check <lang> $(cat batches/b<n>)` and fix everything it reports until it prints `0 file(s) with problems`.
5. Reread two of your lessons as a native reader would and fix anything that sounds translated.
6. Do not commit or push (another process commits the folder periodically; ignore git status). Write only those 10 files.

Final report, 5 lines at most: confirmation that the check passes, any factual doubt about the English source, and any title or name where you departed from the glossary.
