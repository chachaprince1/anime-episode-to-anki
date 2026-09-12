# ImmersionKit Full Card Miner

## Version 1.9.4: row-specific native Anki suggestions

Restored ImmersionKit Anki menus now filter their page-wide suggestions to words present in the clicked result's Japanese sentence. The native handlers remain unchanged, and the extension's full-card button stays available alongside the restored native button.

## Version 1.9.3: settings layout and Anki-navigation feedback

## Version 1.9.2: card-specific capture and original-button preference

- Each full-card button now resolves the result card beside its own Mining control, rather than the first result on the page.
- ImmersionKit’s native Anki control is hidden by default. Settings can restore it as the sole add button, with its compatibility warning.

## Version 1.9.1: exact card selection and one-button workflow

- “View in Anki” now selects the card ID returned by Anki’s Browser search.
- After a card is added or found as a duplicate, the main add button becomes “View in Anki”; no extra page button is created.

## Version 1.9.0: exact Anki navigation and optional direct add

- “View in Anki” now filters the Browser to the card and explicitly selects its note.
- Settings includes a saved “Don’t show preview before adding cards” option. Preview remains on by default.

Local, unpublished Chrome extension for creating new Anki cards from ImmersionKit sentence rows. It needs no ImmersionKit account.

## Version 1.8.2: clear offline-Anki errors

When Anki is closed or AnkiConnect is not listening, the extension now reports **Can't reach AnkiConnect. Open Anki, then try again.** instead of exposing Chrome's generic **Failed to fetch** error. Timeouts still use the separate busy-Anki message.

## Version 1.8.1: one furigana control on the back

The redundant Furigana control inside the Meaning panel has been removed. The back reuses the single closed-by-default Furigana control attached to the Japanese sentence in `FrontSide`, so the reading remains one click away without duplicating the same action below the English answer.

## Version 1.8.0: stronger answer emphasis

On the back of a card, the screenshot now starts at half width. Clicking the screenshot toggles it between compact and full width, while the front keeps the original full-size visual prompt. The Japanese sentence is slightly smaller on desktop and mobile so the English answer has a clearer place in the visual hierarchy without sacrificing readability.

The back continues to reuse `FrontSide`, so Anki does not replay the sentence audio automatically when the answer appears. Unmodified bundled templates from versions 1.5–1.7 upgrade automatically; user-customized templates remain untouched.

## Version 1.7.0: optional furigana and top-position answers

The front and back now each have the same compact **Furigana** control. Both are closed by default and reveal properly rendered ruby readings only when clicked. The control uses the browser's native disclosure element instead of card-template JavaScript for better desktop and mobile reliability.

The back no longer contains Anki's `id=answer` auto-scroll anchor. Flipping a card therefore opens at the top of the question instead of jumping down to the answer, while a visual divider still makes the reveal easy to scan. An untouched bundled version 1.5 or 1.6 template upgrades automatically; customized templates remain untouched.

## Version 1.6.0: polished first-run note type

The bundled **ImmersionKit Full Card** note type now uses a deliberately focused sentence-recognition layout. Its front keeps the original screenshot, Japanese sentence, and authentic audio together. Its answer presents the English meaning first, renders Anki-style Japanese furigana correctly, keeps the source link easy to reach, and puts technical provenance in a collapsible Card details section.

The design is responsive, touch-friendly, and dependency-free. It includes native Japanese font fallbacks for macOS, Windows, and mobile, automatic Anki day/night colors, conditional media and metadata sections, long-sentence handling, and an answer anchor that scrolls directly to the reveal on small screens. It creates only one useful recognition card per mined sentence rather than silently doubling the review queue.

An unmodified version 1.5 template is upgraded automatically. If a user has customized the bundled note type, the extension leaves it untouched. Fresh installations receive the latest design immediately, while every other Anki note type remains available in Settings.

## Version 1.5.0: included Anki template

On first setup, the extension creates an **ImmersionKit Full Card** note type in Anki and recommends it by default. It contains dedicated Sentence, Translation, Furigana, Image, Audio, Source, Source ID, and URL fields plus a responsive recognition-card design. The note-type dropdown still lists every other Anki note type, and the manual mapping dropdown works with all of them. Existing note types with the same name are never overwritten.

Export and Import were removed from Settings. Chrome stores only the selected deck, note type, connection URL, and field mappings locally; the included card template and styling live in Anki with the note type.

## Version 1.4.0: compact mappings and existing-card navigation

Field mapping is now an expandable dropdown in Settings, keeping the common deck and note-type controls compact. Opening a result's gear checks its stable ID against Anki; if that result already exists, Settings shows **View in Anki** and opens the exact note. Trying to add an existing result also returns the existing note instead of a dead-end duplicate error.

## Install locally

1. Keep Anki open with AnkiConnect enabled on port 8765.
2. In Chrome, open `chrome://extensions`, enable **Developer mode**, select **Load unpacked**, then choose this folder.
3. Open ImmersionKit. Each result receives **Add full card to Anki** beside its Mining control.
4. On first use choose an existing deck or create one, choose the note type, and review the manual field mappings. Settings stay only in Chrome's local extension storage.
5. Use the small **⚙** immediately to the right of any Add button to change the deck, note type, or mappings later.

## Version 1.3.1: authoritative card and audio capture

Each result's stable ImmersionKit example ID is now resolved through ImmersionKit's public API. This supplies the exact sentence, translation, furigana, picture, source, and sound filename without scraping combined display text. The extension constructs the real media URL and asks AnkiConnect to download the MP3 and picture into Anki's media collection; cards contain `[sound:filename.mp3]` and `<img>` references, not remote URLs.

Adding a card now has a 12-second total deadline as well as per-request limits. A slow add produces a visible page-level alert: **Your Anki is busy right now; try again later.** The timed-out workflow cannot continue silently in the background.

## Version 1.2.2: audio-link capture

ImmersionKit's player exposes the sound as a React link/click target instead of an `<audio src>`. The extractor now reads that media URL directly from the row (and still checks ordinary audio links and attributes). When the card is created, AnkiConnect downloads the URL into Anki's media collection and the note receives a real `[sound:...]` reference; the URL itself is not merely copied into the card.

## Version 1.2.1: resilient connection handling

AnkiConnect requests time out after eight seconds. If Anki is updating, blocked by an add-on, or otherwise not responding, the button stops spinning and shows: **Your Anki is busy right now; try again later.**

## Version 1.2: preview and settings

Before a note is created, the extension shows a compact preview with editable Japanese sentence, translation, reading, and source title. It reports whether the row exposed its picture and audio, and requires an explicit “Add anyway” choice when either media item is missing. After a successful add, **View in Anki** opens the new note in Anki's browser.

The gear beside every Add button opens settings. It includes a local AnkiConnect URL test, deck and note-type selection, and the field mapper.

## Version 1.1: manual mapping

Every source item has a dropdown listing the selected note type's actual fields. Auto-map suggests familiar field names; all suggestions can be changed. Multiple items can share a destination: they are appended with line breaks in the order shown, never overwritten. Japanese, translation, reading, picture, and audio need destinations. ID, available source title, and page URL are optional.

Settings restore your saved choices. Changing note types refreshes the field list and preserves edits within the open dialog. Validation rejects deleted fields and empty required mappings before creating a deck or saving. Cancel and Escape close the dialog without saving; failed saves keep it open for correction.

The Anki card template controls which fields are visible during review. Mapping stores the data but does not rewrite a custom template. Source title and reading extraction depend on what the page exposes; mapping alone does not guarantee the extractor captured every item correctly.

## Verification

Version 1.3.1 was verified through the installed extension and local AnkiConnect. A real ImmersionKit result produced exact text fields plus stored picture and MP3 media, and the temporary note was then removed. A deliberately non-responsive local Anki endpoint also confirmed that the request is cancelled after eight seconds and the visible busy message appears. JavaScript syntax and the manifest are checked before packaging.

## Design priorities

Research: [Yomitan's Anki integration](https://yomitan.wiki/anki/) and [Anki's editing manual](https://docs.ankiweb.net/editing.html) support explicit field mapping and explain first-field duplicate checks.

Next recommended feature: a source-data adapter resilient to larger ImmersionKit page changes.

## Required Anki fields

The selected note type must contain compatible fields for sentence/expression, translation/English, furigana/reading, image/screenshot, and audio. The supplied `Immersion Kit Sentence` note type works with the built-in mapping:

| Anki field | Source |
| --- | --- |
| Expression | Sentence |
| English | Sentence translation |
| Reading | Sentence with furigana |
| Screenshot | Sentence image |
| Audio Sentence | Sentence audio |
| ID | Sentence |

The extension does not send data to any server. It requests only ImmersionKit pages and local AnkiConnect access. It downloads row media directly into Anki's media collection and prevents duplicates using the ID/sentence field.
