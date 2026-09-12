const { readFileSync } = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");

const ANKI_URL = "http://127.0.0.1:8765";
const stored = { connection: ANKI_URL };
let listener;

const context = vm.createContext({
  TextEncoder,
  URL,
  AbortController,
  setTimeout,
  clearTimeout,
  console,
  fetch,
  chrome: {
    storage: {
      local: {
        get: async (key) => typeof key === "string" ? { [key]: stored[key] } : { ...stored },
        set: async (value) => Object.assign(stored, value)
      }
    },
    runtime: { onMessage: { addListener: (fn) => { listener = fn; } } }
  }
});

vm.runInContext(readFileSync(`${__dirname}/background-v192.js`, "utf8"), context);
const request = (message) => new Promise((resolve) => listener(message, {}, resolve));
const anki = async (action, params = {}) => {
  const response = await fetch(ANKI_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action, version: 6, params })
  });
  const body = await response.json();
  if (body.error) throw new Error(body.error);
  return body.result;
};

(async () => {
  const setup = await request({ type: "setup" });
  assert.equal(setup.ok, true, setup.error);
  assert(setup.result.models.includes("ImmersionKit Full Card"));

  const fields = await anki("modelFieldNames", { modelName: "ImmersionKit Full Card" });
  assert.equal(JSON.stringify(fields), JSON.stringify(["Sentence", "Translation", "Furigana", "Image", "Audio", "Source", "Source ID", "URL"]));
  const templates = await anki("modelTemplates", { modelName: "ImmersionKit Full Card" });
  const styling = await anki("modelStyling", { modelName: "ImmersionKit Full Card" });
  assert.match(templates.Recognition.Front, /template v5/);
  assert.match(templates.Recognition.Front, /{{#Image}}/);
  assert.match(templates.Recognition.Front, /<summary>Furigana<\/summary>/);
  assert.doesNotMatch(templates.Recognition.Back, /{{furigana:Furigana}}/);
  assert.doesNotMatch(templates.Recognition.Back, /<summary>Furigana<\/summary>/);
  assert.match(templates.Recognition.Back, /ik-image-expanded/);
  assert.doesNotMatch(templates.Recognition.Back, /id=["']answer["']/);
  assert.match(templates.Recognition.Back, /Card details/);
  assert.match(styling.css, /\.nightMode, \.night_mode/);
  assert.match(styling.css, /@media \(max-width: 520px\)/);
  assert.match(styling.css, /\.ik-back-context \.ik-media[\s\S]*width: 50%/);
  assert.match(styling.css, /\.ik-sentence[\s\S]*font-size: 31px/);

  const sentence = `拡張機能のテスト ${Date.now()}`;
  let noteId;
  try {
    noteId = await anki("addNote", { note: {
      deckName: setup.result.decks.includes("Immersion Kit") ? "Immersion Kit" : setup.result.decks[0],
      modelName: "ImmersionKit Full Card",
      fields: {
        Sentence: sentence,
        Translation: "A temporary extension template test.",
        Furigana: "拡張[かくちょう] 機能[きのう]のテスト",
        Image: "<div>Picture available</div>",
        Audio: "[sound:immersionkit-template-test.mp3]",
        Source: "Template verification",
        "Source ID": `template-test-${Date.now()}`,
        URL: "https://www.immersionkit.com/"
      },
      tags: ["ImmersionKit", "template-verification"],
      options: { allowDuplicate: false }
    } });
    const cards = await anki("findCards", { query: `nid:${noteId}` });
    assert.equal(cards.length, 1);
    const [card] = await anki("cardsInfo", { cards });
    assert.match(card.question, /Listen · understand/);
    assert.match(card.question, /<details class="ik-furigana-toggle ik-front-hint">/);
    assert.match(card.question, new RegExp(sentence));
    assert.match(card.question, /\[anki:play:q:0\]/);
    assert.match(card.answer, /A temporary extension template test/);
    assert.equal((card.answer.match(/<summary>Furigana<\/summary>/g) || []).length, 1);
    assert.doesNotMatch(card.answer, /ik-back-reading/);
    assert.match(card.answer, /<ruby><rb>拡張<\/rb><rt>かくちょう<\/rt><\/ruby>/);
    assert.match(card.answer, /Template verification/);
    assert.match(card.answer, /Card details/);
  } finally {
    if (noteId) await anki("deleteNotes", { notes: [noteId] });
  }

  console.log("PASS: live model migration, fields, day/night CSS, conditional layout, furigana rendering, and one-card generation.");
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
