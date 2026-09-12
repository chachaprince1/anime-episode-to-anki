const { readFileSync } = require("node:fs");
const vm = require("node:vm");
const assert = require("node:assert/strict");

let listener;
const context = vm.createContext({
  TextEncoder,
  URL,
  AbortController,
  setTimeout,
  clearTimeout,
  fetch: async () => { throw new TypeError("Failed to fetch"); },
  chrome: {
    storage: { local: { get: async () => ({ connection: "http://127.0.0.1:8765" }), set: async () => {} } },
    runtime: { onMessage: { addListener: (fn) => { listener = fn; } } }
  }
});

vm.runInContext(readFileSync(`${__dirname}/background-v192.js`, "utf8"), context);
new Promise((resolve) => listener({ type: "health" }, {}, resolve)).then((reply) => {
  assert.equal(reply.ok, false);
  assert.equal(reply.error, "Can't reach AnkiConnect. Open Anki, then try again.");
  console.log("PASS: an unavailable AnkiConnect produces a clear user-facing error.");
}).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
