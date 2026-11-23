# Adding the new interface keys

`app/source/ui.json` gained keys for the account (sign in, sign out, delete account, progress saved online). For each language you are given:

1. Work in `/home/user/artura/catalog/translations/`. Run `python3 app/app.py check <lang>`: it lists the keys missing from `app/<lang>/ui.json`.
2. Add each missing key with its translation to `app/<lang>/ui.json` (edit the JSON, keep every existing entry unchanged). Context: a row in Settings ("Sign in" / "Account" with a detail line: "Signed in with Apple", "Save your progress online"), an action sheet (Sign out, Delete my account, Cancel), a confirmation alert (title "Delete your account?", message, button "Delete"), an error alert with an "OK" button, and a sign-in sheet (title "Save your progress", subtitle).
3. Same rules as the rest of the app (`app/UI_TASK.md`): informal address where the language uses it (as the existing strings of that language do; read a few), short button labels, Apple's official iOS wording ("Sign Out", "Delete Account", "OK"…), no em dash, Serbian in Latin script, Hebrew addressed in the plural.
4. Run the check again until it reports 0 problems for that language. Write the translations yourself, no machine translation, no delegation. Do not commit.

Final report: one line per language with the check result.
