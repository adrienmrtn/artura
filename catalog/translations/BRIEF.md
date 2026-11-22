# Translating Artura lessons

Artura is an iOS app that teaches art to curious beginners: warm, simple, short sentences, read block by block on a phone. The lessons were written in English. You adapt them into one target language: French (`fr`), Italian (`it`), Spanish (`es`), German (`de`), Brazilian Portuguese (`pt`), Turkish (`tr`), Croatian (`hr`), Norwegian Bokmål (`nb`), Swedish (`sv`), Danish (`da`) or Polish (`pl`).

Folder: `/home/user/artura/catalog/translations/`

- `source/<slug>.json`: the English text of one lesson (only the translatable strings).
- `source/meta.json`: English title, artist, date and museum of the 100 artworks, and the 29 movements.
- `<lang>/meta.json`: the same in the target language. **This is the glossary**: whenever a lesson names one of these artworks, artists or museums, use exactly the form given there.
- `<lang>/lessons/<slug>.json`: what you write. Same JSON structure as the source file: same keys, same number of blocks, spots, lines, quiz questions and options, in the same order. Keep every `"type"` value unchanged.
- Check with `python3 build.py check <lang> <slug> [<slug> ...]` (run from the folder above) and fix every problem it reports.

## This is an adaptation, not a word-for-word translation

Write each sentence the way a good native author of a popular art book would have written it. Read the whole lesson first, then rewrite it block by block.

- Restructure sentences, change the rhythm, pick the natural idiom. Never keep English syntax. If you read your text aloud and it sounds translated, rewrite it.
- Keep the facts, the order of ideas, the tone (direct, a little playful, never academic) and the suspense: a block that ends on a question still ends on a question.
- Address the reader informally and in the singular: `tu` (fr, it), `tú` (es), `du` (de, nb, sv, da), `você` (pt), `sen` (tr), `ti` (hr), `ty` (pl).
- Explain art terms in plain words, as the English does, using the term a museum label would use in your language (sfumato, clair-obscur / chiaroscuro / claroscuro / Helldunkel, etc.).
- Adapt what was written for English speakers. If the English glosses a word that is already in your language, drop the gloss (a French reader does not need “Le Déjeuner sur l'herbe, the luncheon on the grass”). If a pun or a reference does not work, replace it with something that does, or say it plainly.
- Measurements: metric only, drop the imperial equivalents. Numbers and dates in the local format (20 000 francs, 20.000 franchi, 3,5 m). Centuries the local way (XVIIe siècle, il Seicento or XVII secolo, siglo XVII, 17. Jahrhundert). “BC” becomes av. J.-C. (fr), a.C. (it, pt), a. C. (es), v. Chr. (de), MÖ (tr), pr. Kr. (hr), f.Kr. (nb, sv, da), p.n.e. (pl). The examples in this brief are given for the first four languages; apply the same logic to yours.

## Titles and proper names

- The 100 artworks of the catalogue: use `<lang>/meta.json`.
- Any other artwork, book, building or exhibition: use the title under which it is known in your language (museum labels, Wikipedia in that language). Keep the original title when that is the usage (Las Meninas stays Las Meninas in Italian and German, but is Les Ménines in French). Do not invent a translated title: if no established one exists, keep the original and gloss it once if needed.
- People, places, saints, gods, rulers: the established form in your language (Titien / Tiziano / Tiziano / Tizian; Michel-Ange / Michelangelo / Miguel Ángel / Michelangelo; Charles Quint / Carlo V / Carlos V / Karl V.; Florence / Firenze / Florencia / Florenz). Be consistent inside a lesson and with the glossary.
- Quotations: if the person spoke or wrote in your target language and you are confident of the authentic wording, use it. Otherwise translate faithfully. Never embellish a quote.

## Hard constraints

- Quiz: keep the options in the same order (the index of the right answer is stored elsewhere). True/false statements keep their truth value. Every quiz answer must still be found in your translated lesson text, with the same wording for the key term.
- Spot and line texts (`spots[].text`, `lines[].text`) appear in a small card: aim for 250 characters or fewer, never more than 300. Spot titles and line labels: 1 to 4 words. The teaser: one sentence, at most 130 characters.
- No em dashes. No markdown, no emojis, no headings.
- Quotation marks: fr « texte », it «testo», es «texto», de „Text“, pt “texto”, tr “metin”, hr „tekst“, nb «tekst», sv ”text”, da »tekst«, pl „tekst”. An apostrophe is the straight `'` or `’` as in the source.
- Valid JSON, UTF-8, real characters (é, ß, ñ), not escape sequences.
- Do not add or remove information. Do not correct facts; if you think the English is factually wrong, translate it as it is and mention it in your final report.

## Working rules

Write only the files you are asked for. Do not commit, do not push, do not touch any other file.


## Additional languages (read after the rules above; they win in case of conflict)

Besides the languages named at the top, you may be asked for: European Portuguese (`pt-PT`, not Brazilian: use Portugal's vocabulary, spelling and `tu`), Romanian (`ro`), Dutch (`nl`), Greek (`el`), Hungarian (`hu`), Bulgarian (`bg`), Czech (`cs`), Russian (`ru`), Slovenian (`sl`), Slovak (`sk`), Serbian in Latin script (`sr`, ekavian, as in Serbia), Arabic (`ar`, Modern Standard Arabic), Hebrew (`he`), Finnish (`fi`), Estonian (`et`), Lithuanian (`lt`), Latvian (`lv`), Japanese (`ja`).

- Address: the informal singular a friendly app would use (`tu`, `du`, `je`, `ty`, `ти`, `sinä`, `sina`, `te`, `εσύ`...). Japanese: polite です・ます style, and leave the pronoun out where Japanese does. Arabic and Hebrew: avoid gender-marked address when the sentence lets you; otherwise use the masculine singular.
- Quotation marks, dashes, spacing before punctuation, thousands separators and date formats: the standard typographic conventions of the language. Still no em dashes.
- BC: use the established abbreviation of your language (e.g. ro î.Hr., nl v.Chr., el π.Χ., hu i. e., bg пр.Хр., cs př. n. l., ru до н. э., sl pr. n. št., sk pred Kr., sr p. n. e., ar ق.م, he לפנה"ס, fi eKr., et eKr, lt pr. Kr., lv p.m.ē., ja 紀元前).
- Right-to-left (ar, he): write plain text; do not insert directional marks; keep Western digits; Latin-script names (e.g. in titles you keep in the original) stay as they are.
- Scripts: names of artists and places follow the transliteration actually used in your language (Cyrillic, Greek, Arabic, Hebrew, Japanese katakana/kanji). The same name must be written the same way everywhere.
- Character limits in this brief (teaser 130, spot/line text 300) count characters; they are comfortable for every language, but keep spot texts short in all of them.
