# Translating the app's interface

You are given a target language (name and folder code `<lang>`). You are a native UX writer in that language, localising a polished consumer iOS app (Artura: learn art history in a few minutes a day: daily artwork feed, lessons on paintings with zoom and guided tours, quizzes, games, review, streaks, subscription paywall, home-screen widget).

1. Work in `/home/user/artura/catalog/translations/`. Read `BRIEF.md` (tone and typography rules; same register as the lessons, the user is addressed informally where the language allows it: tu, du, tú, ty…) and `<lang>/meta.json` (names of artworks, artists, movements in your language).
2. Read `app/source/ui.json`: an object whose keys are the English interface strings and whose values are the Swift file where each is used. Open the Swift file whenever the context is unclear (button? title? sentence continued by another key? `// L:` comments explain split sentences). Write `app/<lang>/ui.json`: a JSON object with **every** key of the source, each mapped to its translation (the value is your text, not the file name).
3. Rules:
   - `%@` are values inserted by the app (numbers, names, dates). Keep exactly as many as the key. To reorder, use `%1$@`, `%2$@`. In a key that contains `%@` or `%%`, a literal percent sign is written `%%`; in any other key, write a plain `%`.
   - Keep markdown markers (`**bold**`) and `\n` line breaks where they are.
   - Buttons and tab names short: they must fit the same space as the English (a German or Finnish word can be long: pick the shorter natural option). Titles in sentence case unless your language's iOS convention differs.
   - Plurals: when the code has separate keys for 1 and many, translate each naturally; for languages with several plural forms (Slavic, Baltic, Arabic…), word the "many" key so it is correct for any number ≥ 2 (for example "Lessons: %@" or a noun form that works), never a form that is wrong for 2–4.
   - Paywall, subscription and trial wording must stay precise (prices, durations, "cancel anytime", renewal): translate the meaning exactly, no embellishment.
   - Keep brand names (Artura, Google, Apple, App Store) as they are; use Apple's official wording in your language for iOS terms (Home Screen, widget, Settings, notifications, Sign in with Apple, Restore Purchases…).
   - Art terms and names follow your glossary.
4. Write it yourself with care, no machine-translation shortcut, no script producing text, no delegation. You may write the file in a few chunks with the Write/Edit tools.
5. Run `python3 app/app.py check <lang>` and fix every problem listed under `ui.json` until there is none (ignore the lines about `content.json`, another agent handles it).
6. Reread the onboarding and paywall strings as a native user would and polish anything that sounds translated. Do not commit or push. Write only that one file.

Final report, 4 lines at most: check result, keys whose meaning was unclear to you.
