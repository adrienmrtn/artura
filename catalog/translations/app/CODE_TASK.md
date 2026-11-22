# Making the app's interface translatable (code pass)

The iOS app (SwiftUI, `/home/user/artura/Artura`, widget in `/home/user/artura/ArturaWidget`) has all its interface text hard-coded in English. It must become translatable into 29 languages. Your job: in the files you are given, route **every piece of text a user can see** through the function `L` defined in `Artura/Core/Localization.swift` (read it first). You do not translate anything; a script will later collect every `L("…")` key and translators will translate them.

There is no Swift compiler here. Every edit must compile on the first try in Xcode: be conservative, keep types right, change nothing else.

## The API
- `L("Continue")` returns a `String`.
- With values: `L("%@ lessons left", "\(count)")`. Only `%@` placeholders, one per value, values passed as `String` (`"\(n)"`, `name`, …). Never `%d`/`%lld`.
- The first argument must always be a **plain string literal on one line**, written exactly as the English text shown today (so the script can find it). No string concatenation, no interpolation inside the key, no multi-line `"""` literals (split a multi-line literal into one key per paragraph only if the code already joins them; otherwise keep one key with `\n` inside).

## How to convert
- `Text("Continue")` -> `Text(L("Continue"))`. `Text("You have \(n) days")` -> `Text(L("You have %@ days", "\(n)"))`.
- `Button("Save") {…}` -> `Button(L("Save")) {…}`. Same for `Label`, `Toggle`, `.navigationTitle`, `.alert`, `.confirmationDialog`, `TextField` placeholder, `.accessibilityLabel`, `Section` headers, `ShareLink` subjects/messages, notification titles/bodies, widget `.configurationDisplayName` / `.description`, etc.
- Helper functions or structs that receive the text as `String` (`row("globe", "Language", …)`, `title: "Welcome"`, arrays of option labels, `switch` returning a label): wrap the literal **at the call site / where the literal is written**: `row("globe", L("Language"), …)`. Do not change parameter types.
- If a helper takes `LocalizedStringKey`, passing `L(…)` (a `String`) does NOT compile: pass `LocalizedStringKey(L("…"))`. Check each helper's parameter type before you pass `L(…)` to it. Prefer changing the call over changing the helper. Note `Text(someStringVariable)` shows the string verbatim (fine, it is already translated).
- **Markdown**: `Text("Read **one** artwork")` with a literal renders the bold today. `Text(L(…))` would show the asterisks. Where a literal contains `**`, `*`, `_` or `[link](url)` markdown, use `Text(LocalizedStringKey(L("Read **one** artwork")))`, keep the markdown inside the key. Same for `AttributedString(markdown:)` code: just wrap the literal.
- Sentences built from pieces (`Text("Hello ") + Text(name).bold() + Text("!")`): replace by one key with a placeholder when the styling allows (`L("Hello %@!", name)`). If the pieces are styled differently and must stay separate, keep them separate but make each piece a full meaningful key, and add a `// L: …` comment explaining the sentence to translators right above.
- Plurals done in code (`n == 1 ? "1 lesson" : "\(n) lessons"`): keep the code, wrap both branches as full keys (`L("1 lesson")`, `L("%@ lessons", "\(n)")`).
- Dates: a formatter forced to `Locale(identifier: "en_US")` for display must use `AppLanguage.locale` instead (keep `en_US_POSIX` for storage/parsing formats).
- Text that is only a number, a symbol, an emoji, a year, a URL, a brand ("Artura", "Google", "Apple") alone: leave as is.
- Upper-casing in code (`.uppercased()`, `.textCase(.uppercase)`) is fine; keep it.

## Do NOT wrap
Identifiers and data: SF Symbol names, image/asset names, colors, `UserDefaults`/`@AppStorage` keys, notification identifiers, product IDs, URLs, analytics/event names, JSON keys, `type` values like `"tour"`, `switch` cases compared against data, debug `print`/log text, `#Preview` content, comments. If a string is both shown AND used as an identifier (compared, stored, used as a key), do not wrap it at the definition: wrap it where it is displayed only (`Text(L(option))` is NOT allowed since the key must be a literal; instead introduce a small `switch`/dictionary mapping the identifier to `L("literal")` labels, or leave it and report it).

## Workflow
1. Read `Artura/Core/Localization.swift`, then each of your files completely.
2. Edit with the Edit tool (no sed/regex rewriting of whole files).
3. After each file, grep it for remaining user-visible English literals and double-check every changed line for compile errors (types, parentheses, `LocalizedStringKey` vs `String`).
4. Edit only your files. Do not commit or push. Do not touch `Artura/Data/Models.swift`, `Artura/Data/RemoteCatalog.swift` or `Localization.swift` (owned by someone else).

Final report, 8 lines at most: files done, any string you deliberately left unwrapped and why, anything you are unsure compiles.
