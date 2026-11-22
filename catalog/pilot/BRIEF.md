# Writing lessons for Artura

Artura is an iOS app that teaches art to curious beginners, in the spirit of Headspace: warm, simple, short sentences, direct address ("you"). A lesson is read block by block on a phone. Some blocks open the artwork full screen and move a camera over it.

You write one JSON file per artwork: `lessons/<slug>.json` in this folder
(`the working folder`).

## Process, for each artwork

1. Read its row in `pilot.json` (title, artist, year, museum, kind, movement_id).
2. LOOK at the image with the Read tool: `img/<slug>_grid.jpg` (the artwork with a yellow 10x10 grid; column and row lines are numbered 1 to 9, so the line "3" is at 0.30). Also open `img/<slug>.jpg` (no grid) if you need a cleaner view. Every coordinate you write must come from what you see in this image, never from your memory of the artwork. If a detail you wanted to point at is not visible or not where you expected, drop it or pick another.
3. Write the lesson.
4. Run `python3 validate.py lessons/<slug>.json` and fix every error.

## JSON format

```json
{
  "teaser": "One sentence shown on the artwork card. Intriguing, under 110 characters.",
  "focus": [0.5, 0.4],
  "review_notes": "Claims a human should double-check, one per line. Empty string if none.",
  "lesson": [ ...blocks... ],
  "quiz": [ {"question": "...", "options": ["a","b","c"], "answer": 1, "explanation": "..."} ],
  "facts": [ {"text": "A statement.", "isTrue": false, "explanation": "..."} ]
}
```

`focus` is the most interesting point of the image (normalised x, y from the top left), used to crop thumbnails.

### Reading blocks

- `{"type":"text","text":"..."}`: one short paragraph, 1 to 4 sentences, about 150 to 380 characters.
- `{"type":"key","text":"..."}`: a key takeaway, one or two sentences, something worth remembering in a year.
- `{"type":"fact","text":"..."}`: shown in a "Did you know?" card. A surprising, concrete, true anecdote (a price, a theft, a habit of the artist, a material, a scandal). Do not start it with "Did you know".

### Interactive blocks (the artwork opens full screen)

All coordinates are normalised 0..1 from the top-left corner of the image.

- **tour**: the camera travels to 2 to 4 details, one tap each.
  `{"type":"tour","title":"optional short title","text":"Shown over the whole image before the first tap.","spots":[{"x":0.4,"y":0.38,"zoom":2.6,"r":0.12,"shape":"circle","title":"The gaze","text":"What to notice here, max 230 characters."}]}`
- **find**: the user is asked to tap something on the image before it is revealed. Exactly one spot.
  `{"type":"find","text":"The question, e.g. 'There is a dog in this crowd. Where?'","spots":[{"x":..,"y":..,"zoom":3,"r":0.06,"title":"The dog","text":"The explanation shown after the tap."}]}`
  Only ask for things a beginner can actually find by looking. Not too easy, never impossible.
- **lines**: 2 to 4 lines drawn over the image one at a time (composition, direction of gazes, where light comes from, a hidden geometric shape).
  `{"type":"lines","text":"Intro shown before the first line.","lines":[{"points":[[0.1,0.2],[0.5,0.6]],"closed":false,"label":"The diagonal","text":"Why it matters, max 230 characters."}]}`
  `closed: true` closes the polygon (triangles, circles approximated by 8+ points).
- **explore**: free pinch-zoom with 4 to 8 tappable hotspots. `{"type":"explore","spots":[...]}`. Spots may repeat details from earlier blocks or add new ones.

Spot fields: `x`, `y` centre of the detail; `zoom` 1.3 to 5 (how much the camera magnifies; small details need 3 to 4, large areas 1.5 to 2); `r` radius of the marker as a fraction of the image WIDTH (0.03 to 0.3, sized to enclose the detail); `shape` is `"circle"` (default), `"rect"` (taller than wide, for standing figures, trees, columns) or `"arrow"` (for a tiny point); `title` 1 to 4 words; `text` max 230 characters.

## What the user asked for (the important part)

1. **No template.** These lessons will be read one after another. They must not share a skeleton or recurring phrasings. Across the artworks you write, deliberately vary:
   - the opening: a question, a scene, a scandal, a misconception, a number, a sound or smell, a detail before the whole... never twice the same kind;
   - the length: between 12 and 22 blocks, depending on how much the work has to say;
   - the order and mix of blocks; where the first interactive block lands; how the lesson ends (a question left open, a later consequence, a return to the first image, a fact...). Do not always end with `explore`, and do not always end with a `key`.
   - sentence shapes and vocabulary. Avoid stock phrases such as "Look closely", "Take a moment", "Let's dive in", "At first glance", "But there's more", "Here's the thing", "masterpiece" in every lesson.
2. **Zooms only when they help understanding.** Use an interactive block when seeing the detail is the point: a hidden figure, a brushstroke, an expression, a symbol, the construction of the picture. Do not add one because "a lesson needs one". Some works deserve five interactive moments, some deserve one or two (a nearly monochrome abstract painting does not need a guided tour of four details). Vary the kind: not every lesson needs tour + find + lines.
3. **Every zoom is tied to its text.** The reading block just before an interactive block must lead into it (raise the question the zoom answers), and the block just after must build on what was just seen. The spot text explains what is visible in that exact region.
4. **Never two interactive blocks in a row**, and never as the first block. Between two interactive blocks, put at least two reading blocks most of the time.
5. **"Did you know?" facts**: 2 to 4 `fact` blocks per lesson, spread out, each on a different kind of subject.
6. **Go beyond description.** A lesson is not a list of what is in the picture. Mix: the story of its making, the artist's life at that moment, the technique and materials, what was new, how people reacted, what happened to the object afterwards, what it changed for later artists, and how to look at it. Explain every art term the first time (in plain words, in the same sentence).

## Quiz and true/false

- `quiz`: 4 to 6 questions, 3 options each, `answer` is the 0-based index. **Every question must be answerable from the lesson text alone** (reading blocks or spot texts). Never ask about something the lesson did not say. Vary which option is correct. The explanation is one short sentence.
- `facts`: exactly 3 true/false statements for a mini-game, mixing true and false, also grounded in the lesson. `explanation` says why in one sentence.

## Accuracy

- Write only what you are confident is true. No invented quotes, dates, prices or anecdotes. If you are fairly sure but not certain of a claim, either leave it out or keep it and list it in `review_notes`.
- Use the title, artist, year and museum from `pilot.json`. If you believe one of them is wrong, say so in `review_notes` rather than silently contradicting it.
- For sculptures and photographs of objects, the image is one photo from one angle: point only at what this photo shows.

## Style

- American English. Present tense for describing the work, past tense for history.
- Plain words. No em dashes (use commas, periods or colons). Typographic quotes “ ” inside text are fine.
- No headings, no markdown, no emojis inside the JSON strings.
- Dimensions: give metric with an approximate imperial equivalent when size matters.
