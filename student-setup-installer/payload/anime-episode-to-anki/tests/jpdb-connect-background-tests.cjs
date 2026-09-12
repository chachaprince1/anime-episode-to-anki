const assert = require("node:assert/strict");
const crypto = require("node:crypto").webcrypto;
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const state = {
  settings: {jpdbApiKey: "", filters: {skipParticles: false}}
};
const session = {};
const opened = [];
const testKey = "a".repeat(32);
let pingCount = 0;

const context = vm.createContext({
  AbortController,
  clearTimeout,
  console,
  crypto,
  Date,
  fetch: async (url, options) => {
    pingCount += 1;
    assert.equal(String(url), "https://jpdb.io/api/v1/ping");
    assert.equal(options.headers.Authorization, `Bearer ${testKey}`);
    assert.equal(options.credentials, "omit");
    return new Response("{}", {status: 200});
  },
  Response,
  setTimeout,
  Uint8Array,
  URL,
  JYACore: {
    mergeSettings(value) {
      return {jpdbApiKey: "", filters: {skipParticles: true}, ...value};
    }
  },
  chrome: {
    tabs: {async create(value) { opened.push(value); }},
    storage: {
      local: {
        async get(key) { return {[key]: state[key]}; },
        async set(value) { Object.assign(state, value); }
      },
      session: {
        async get(key) { return {[key]: session[key]}; },
        async set(value) { Object.assign(session, value); },
        async remove(key) { delete session[key]; }
      }
    }
  }
});
vm.runInContext(fs.readFileSync(path.join(root, "jpdb-connect-background.js"), "utf8"), context, {
  filename: "jpdb-connect-background.js"
});

(async () => {
  const bridge = context.JYAJpdbConnect;
  assert.deepEqual(JSON.parse(JSON.stringify(await bridge.begin())), {started: true});
  assert.equal(opened.length, 1);
  const firstUrl = new URL(opened[0].url);
  assert.equal(firstUrl.origin + firstUrl.pathname, "https://jpdb.io/settings");
  const firstNonce = firstUrl.hash.slice("#jya-connect=".length);
  assert.match(firstNonce, /^[a-f\d]{48}$/);

  await assert.rejects(
    bridge.complete({nonce: firstNonce, apiKey: testKey}, {url: "https://example.com/settings"}),
    /did not come from jpdb settings/
  );
  assert.equal(state.settings.jpdbApiKey, "");
  assert.equal(pingCount, 0);

  await bridge.begin();
  const secondUrl = new URL(opened[1].url);
  const secondNonce = secondUrl.hash.slice("#jya-connect=".length);
  await assert.rejects(
    bridge.complete({nonce: "0".repeat(48), apiKey: testKey}, {url: secondUrl.href}),
    /does not match/
  );
  assert.equal(state.settings.jpdbApiKey, "");
  assert.equal(pingCount, 0);
  assert.equal(session.jpdbConnectAttempt.nonce, secondNonce, "a mismatched nonce must not cancel the valid attempt");

  await bridge.begin();
  const thirdUrl = new URL(opened[2].url);
  const thirdNonce = thirdUrl.hash.slice("#jya-connect=".length);
  const result = await bridge.complete(
    {nonce: thirdNonce, apiKey: testKey},
    {url: thirdUrl.href, tab: {url: thirdUrl.href}}
  );
  assert.deepEqual(JSON.parse(JSON.stringify(result)), {connected: true});
  assert.equal(pingCount, 1);
  assert.equal(state.settings.jpdbApiKey, testKey);
  assert.equal(state.settings.filters.skipParticles, false, "existing setup choices must be preserved");
  assert.equal(session.jpdbConnectAttempt, undefined, "successful attempts must be consumed");

  await assert.rejects(
    bridge.complete({nonce: thirdNonce, apiKey: testKey}, {url: thirdUrl.href}),
    /expired/
  );
  assert.equal(pingCount, 1, "a replay must fail before contacting jpdb");
  console.log("jpdb connection background tests passed");
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
