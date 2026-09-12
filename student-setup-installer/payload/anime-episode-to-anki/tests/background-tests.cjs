const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const listeners = {message: null, connect: null, installed: null};
const storageState = {
  settings: {
    jpdbApiKey: "secret",
    yomitanUrl: "http://127.0.0.1:19633",
    ankiUrl: "http://127.0.0.1:8765",
    maxYomitanEntries: 8,
    formatIndex: 0
  }
};
const sessionStorageState = {jpdbConnectAttempt: {nonce: "test", createdAt: Date.now()}};
const requests = [];
const createdTabs = [];
let storageAccessLevel = "";
let cancelOnYomitanLookup = false;
let cancelled = false;

function jsonResponse(value, status = 200) {
  return new Response(JSON.stringify(value), {status, headers: {"Content-Type": "application/json"}});
}

async function mockFetch(url, options = {}) {
  const body = options.body ? JSON.parse(options.body) : undefined;
  requests.push({url: String(url), body});
  if (String(url).endsWith("/api/v1/deck/list-vocabulary")) {
    assert.equal(options.headers.Authorization, "Bearer secret");
    assert.deepEqual(body, {id: 123, fetch_occurence: true});
    return jsonResponse({vocabulary: [[2028920, 1], [1808780, 1]], occurences: [19, 34]});
  }
  if (String(url).endsWith("/api/v1/ping")) return jsonResponse({});
  if (String(url).endsWith("/api/v1/lookup-vocabulary")) {
    return jsonResponse({vocabulary_info: [
      ["は", "は", 1, ["topic marker"]],
      ["高木", "たかぎ", 4500, ["Takagi"]]
    ]});
  }
  if (String(url).endsWith(":19633/serverVersion")) return jsonResponse({version: 1});
  if (String(url).endsWith(":19633/ankiCardFormats")) {
    return jsonResponse([{name: "Expression", deck: "Mining", model: "Japanese", type: "term", fields: {
      Expression: {value: "{expression}"},
      Reading: {value: "{reading}"},
      Meaning: {value: "{glossary}"}
    }}]);
  }
  if (String(url).endsWith(":19633/ankiFields")) {
    if (cancelOnYomitanLookup) cancelled = true;
    assert.ok(body.markers.includes("expression") && body.markers.includes("glossary"));
    const values = body.text === "高木"
      ? [{expression: "高木", reading: "こうぼく", glossary: "tall tree"}, {expression: "高木", reading: "たかぎ", glossary: "Takagi"}]
      : [{expression: body.text, reading: body.text, glossary: "particle"}];
    return jsonResponse({fields: values, dictionaryMedia: [], audioMedia: []});
  }
  if (String(url).startsWith("http://127.0.0.1:8765")) {
    if (body.action === "version") return jsonResponse({result: 6, error: null});
    if (body.action === "modelFieldNames") return jsonResponse({result: ["Expression", "Reading", "Meaning"], error: null});
    if (body.action === "createDeck") return jsonResponse({result: 1234, error: null});
    if (body.action === "multi") {
      assert.equal(body.params.actions[1].params.note.fields.Meaning, "Takagi", "jpdb reading should select the matching Yomitan result");
      return jsonResponse({result: [
        {result: 991, error: null},
        {result: null, error: "cannot create note because it is a duplicate"}
      ], error: null});
    }
  }
  throw new Error(`Unexpected fetch: ${url}`);
}

function eventSlot(name) {
  return {addListener(callback) { listeners[name] = callback; }};
}

const context = vm.createContext({
  console,
  URL,
  Response,
  AbortController,
  setTimeout,
  clearTimeout,
  btoa,
  fetch: mockFetch,
  importScripts() {},
  chrome: {
    runtime: {
      onInstalled: eventSlot("installed"),
      onMessage: eventSlot("message"),
      onConnect: eventSlot("connect"),
      getURL(value) { return `chrome-extension://test/${value}`; },
      async openOptionsPage() {}
    },
    tabs: {async create(options) { createdTabs.push(options); }},
    storage: {
      local: {
        async setAccessLevel({accessLevel}) { storageAccessLevel = accessLevel; },
        async get(key) { return typeof key === "string" ? {[key]: storageState[key]} : {...storageState}; },
        async set(value) { Object.assign(storageState, value); }
      },
      session: {
        async get(key) { return typeof key === "string" ? {[key]: sessionStorageState[key]} : {...sessionStorageState}; },
        async set(value) { Object.assign(sessionStorageState, value); },
        async remove(key) { delete sessionStorageState[key]; }
      }
    }
  }
});
vm.runInContext(fs.readFileSync(path.join(root, "core.js"), "utf8"), context, {filename: "core.js"});
vm.runInContext(fs.readFileSync(path.join(root, "background.js"), "utf8"), context, {filename: "background.js"});

function sendMessage(message, sender = {url: "chrome-extension://test/onboarding.html"}) {
  return new Promise((resolve) => {
    const keepAlive = listeners.message(message, sender, resolve);
    assert.equal(keepAlive, true);
  });
}

function runPortJob(payload, senderUrl = "https://jpdb.io/deck?id=123") {
  return new Promise((resolve, reject) => {
    const inbound = [];
    const disconnected = [];
    const port = {
      name: "jpdb-yomitan-import",
      sender: {url: senderUrl},
      onMessage: {addListener(callback) { inbound.push(callback); }},
      onDisconnect: {addListener(callback) { disconnected.push(callback); }},
      postMessage(message) {
        if (message.type === "complete") resolve(message.result);
        if (message.type === "error") reject(new Error(message.error));
      },
      disconnect() { disconnected.forEach((callback) => callback()); }
    };
    listeners.connect(port);
    inbound.forEach((callback) => callback({type: "start", payload}));
  });
}

(async () => {
  assert.equal(storageAccessLevel, "TRUSTED_CONTEXTS");

  const contentResponse = await sendMessage(
    {type: "getContentSettings"},
    {url: "https://jpdb.io/anime/758/example"}
  );
  assert.equal(contentResponse.ok, true);
  assert.equal(contentResponse.result.hasJpdbApiKey, true);
  assert.equal("jpdbApiKey" in contentResponse.result, false, "content settings must redact the jpdb key");
  assert.equal("ankiUrl" in contentResponse.result, false, "content settings must redact local service addresses");

  const savedResponse = await sendMessage({
    type: "saveContentPreferences",
    preferences: {
      jpdbApiKey: "attacker-value",
      ankiUrl: "http://attacker.invalid",
      includeMedia: true,
      formatIndex: 7,
      filters: {skipParticles: false, minimumOccurrences: 500, unexpected: true},
      customExcludedIds: ["attacker-value"]
    }
  }, {url: "https://jpdb.io/deck?id=123"});
  assert.equal(savedResponse.ok, true);
  assert.equal(storageState.settings.jpdbApiKey, "secret", "content preferences must not overwrite the API key");
  assert.equal(storageState.settings.ankiUrl, "http://127.0.0.1:8765", "content preferences must not overwrite connection addresses");
  assert.equal(storageState.settings.includeMedia, true);
  assert.equal(storageState.settings.formatIndex, 7);
  assert.equal(storageState.settings.filters.skipParticles, false);
  assert.equal(storageState.settings.filters.minimumOccurrences, 99);
  assert.equal(storageState.settings.customExcludedIds.length, 0);

  const rejectedSave = await sendMessage(
    {type: "saveContentPreferences", preferences: {includeMedia: false}},
    {url: "https://jpdb.io/anime/758/example"}
  );
  assert.equal(rejectedSave.ok, false);
  const rejectedBegin = await sendMessage(
    {type: "beginJpdbConnection"},
    {url: "https://jpdb.io/settings"}
  );
  assert.equal(rejectedBegin.ok, false, "only the extension setup may begin a credential handoff");

  assert.equal((await sendMessage({type: "openYomitanApiSettings"})).ok, true);
  assert.match(createdTabs.at(-1).url, /settings\.html#general$/);
  assert.equal((await sendMessage({type: "openYomitanSettings"})).ok, true);
  assert.match(createdTabs.at(-1).url, /settings\.html#anki$/);

  const rejectedDeckResponse = await sendMessage(
    {type: "getJpdbDeckWords", deckId: 123},
    {url: "https://evil.example/deck?id=123"}
  );
  assert.equal(rejectedDeckResponse.ok, false);
  const deckResponse = await sendMessage(
    {type: "getJpdbDeckWords", deckId: 123},
    {url: "https://jpdb.io/deck?id=123"}
  );
  assert.equal(deckResponse.ok, true);
  assert.equal(deckResponse.result.words.length, 2);
  assert.deepEqual(JSON.parse(JSON.stringify(deckResponse.result.words[1])), {
    jpdbId: "1808780", sid: "1", spelling: "高木", reading: "たかぎ",
    frequencyRank: 4500, meanings: ["Takagi"], occurrences: 34
  });

  const result = await runPortJob({
    target: "anki",
    words: deckResponse.result.words,
    formatIndex: 0,
    deckName: "JPDB::Test",
    includeMedia: false,
    tags: ["Test Episode"]
  });
  assert.equal(result.added, 1);
  assert.equal(result.duplicates, 1);
  assert.equal(result.failures.length, 0);
  assert.equal(result.generated, 2);

  const exported = await runPortJob({
    target: "export",
    words: [deckResponse.result.words[1]],
    formatIndex: 0,
    deckName: "JPDB::Test",
    includeMedia: true,
    tags: ["Test Episode"]
  });
  assert.match(exported.tsv, /#notetype:Japanese/);
  assert.match(exported.tsv, /#columns:Expression\tReading\tMeaning/);
  assert.match(exported.tsv, /高木\tたかぎ\tTakagi/);
  assert.equal(exported.exportFieldOrderVerified, true);
  assert.equal(requests.some((request) => request.url.includes("/ankiFields")), true);

  let rejectedPortDisconnected = false;
  let rejectedPortAcceptedMessage = false;
  listeners.connect({
    name: "jpdb-yomitan-import",
    sender: {url: "https://jpdb.io/anime/758/example"},
    onMessage: {addListener() { rejectedPortAcceptedMessage = true; }},
    onDisconnect: {addListener() {}},
    postMessage() {},
    disconnect() { rejectedPortDisconnected = true; }
  });
  assert.equal(rejectedPortDisconnected, true, "non-deck import ports must be disconnected");
  assert.equal(rejectedPortAcceptedMessage, false, "non-deck import ports must not receive handlers");

  const multiRequestsBeforeCancel = requests.filter((request) => request.body?.action === "multi").length;
  cancelOnYomitanLookup = true;
  await assert.rejects(
    context.runImport({
      target: "anki",
      words: [deckResponse.result.words[1]],
      formatIndex: 0,
      deckName: "JPDB::Cancelled",
      includeMedia: false,
      tags: []
    }, () => {}, () => cancelled),
    /Import cancelled/
  );
  const multiRequestsAfterCancel = requests.filter((request) => request.body?.action === "multi").length;
  assert.equal(multiRequestsAfterCancel, multiRequestsBeforeCancel, "cancellation after lookup must prevent the Anki batch");

  const rejectedClear = await sendMessage(
    {type: "clearJpdbConnection"},
    {url: "https://jpdb.io/deck?id=123"}
  );
  assert.equal(rejectedClear.ok, false);
  assert.equal(storageState.settings.jpdbApiKey, "secret");
  const cleared = await sendMessage({type: "clearJpdbConnection"});
  assert.equal(cleared.ok, true);
  assert.equal(storageState.settings.jpdbApiKey, "");
  assert.equal("jpdbConnectAttempt" in sessionStorageState, false);
  assert.equal(fs.readFileSync(path.join(root, "content.js"), "utf8").includes("chrome.storage.local"), false,
    "the jpdb content script must not have direct access to extension-local storage");
  console.log("Background integration tests passed");
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
