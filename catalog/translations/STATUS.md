# Translation status (handover)

100 lessons (`selection.txt`) are being adapted from English. Read `BRIEF.md` (rules) and `TASK.md` (how one batch of 10 is done); `build.py` extracts, checks and merges.

## Done, checked, pushed
- fr, it, es, de: glossary (`<lang>/meta.json`) + 100 lessons each; `python3 build.py check <lang>` reports 0 problems.

## In progress (agents were stopped mid-batch)
- pt (Brazilian Portuguese): glossary done, 86 of 100 lessons written; every written file passes the check, but only batch 8 had its final reread.
- nb (Norwegian Bokmål): glossary done, 83 of 100 lessons written; every written file passes the check, none had its final reread.

Missing files:
```
pt missing:
  bosch-the-garden-of-earthly-delights
  botticelli-the-birth-of-venus
  younger-the-ambassadors
  rubens-the-three-graces
  bernini-apollo-and-daphne
  brun-self-portrait-in-a-straw-hat
  david-the-death-of-marat
  hayez-the-kiss
  hokusai-the-great-wave-off-kanagawa
  sargent-madame-x
  degas-the-dance-class
  rousseau-the-sleeping-gypsy
  munch-the-scream
  hoa-hakananai-a-moai
nb missing:
  weyden-the-descent-from-the-cross
  bosch-the-garden-of-earthly-delights
  botticelli-the-birth-of-venus
  durer-young-hare
  younger-the-ambassadors
  rubens-the-three-graces
  bernini-apollo-and-daphne
  fragonard-the-swing
  brun-self-portrait-in-a-straw-hat
  david-the-death-of-marat
  hayez-the-kiss
  hokusai-the-great-wave-off-kanagawa
  sargent-madame-x
  degas-the-dance-class
  rousseau-the-sleeping-gypsy
  munch-the-scream
  hoa-hakananai-a-moai
```

## Not started (glossary done, 0 lessons)
- tr, hr, sv, da, pl

## Supabase (project "Artura", dsbhaddvzpswkjzqskhv): nothing loaded yet
1. Apply `supabase/migrations/20261122120000_translations.sql` (never applied: the approval prompt timed out twice). It creates six `*_translations` tables and two loader functions in schema `private`; English tables are untouched.
2. `python3 build.py merge <lang>` writes `build/<lang>/<slug>.json` (translated text + English coordinates and quiz answers + `meta`; `build/` is git-ignored).
3. Load each file with `select private.upsert_lesson_translation('<slug>', '<lang>', '<json>'::jsonb)` and each language's movements with `select private.upsert_movement_translations('<lang>', '<meta.json movements>'::jsonb)`. About 1 MB per language: too much to paste through the SQL tool by hand, so it needs a write path from the container (the REST endpoint is reachable with the anon key, which is read-only).

## Not done
- The iOS app still reads only the English tables.
- Source inconsistencies reported by translators (Marc "two details" for three spots, Creation of Adam "three places" for four spots, Las Meninas nine vs eleven figures, Jonghelinck spelling, Bosch "strawberry") are unresolved in the English, and handled differently across languages for the Marc one.
