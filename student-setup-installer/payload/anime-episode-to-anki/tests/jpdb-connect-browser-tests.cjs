const assert = require("node:assert/strict");
const path = require("node:path");
const {chromium} = require("playwright");

const extensionRoot = path.resolve(__dirname, "..");
const nonce = "b".repeat(48);
const apiKey = "c".repeat(32);

(async () => {
  const browser = await chromium.launch({
    headless: true,
    executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  });
  try {
    const context = await browser.newContext();
    await context.addInitScript(() => {
      globalThis.__messages = [];
      globalThis.chrome = {
        runtime: {
          async sendMessage(message) {
            globalThis.__messages.push(message);
            return {ok: true, result: {connected: true}};
          }
        }
      };
    });
    await context.route("https://jpdb.io/settings*", (route) => route.fulfill({
      status: 200,
      contentType: "text/html",
      body: `<!doctype html><html><body><main><h1>Settings</h1><table><tbody>
        <tr><td>Username</td><td>test-user</td></tr>
        <tr><td>API key</td><td>${apiKey}</td></tr>
      </tbody></table></main></body></html>`
    }));
    const page = await context.newPage();
    await page.goto(`https://jpdb.io/settings#jya-connect=${nonce}`);
    await page.addScriptTag({path: path.join(extensionRoot, "jpdb-connect.js")});
    assert.equal(await page.evaluate(() => globalThis.__messages.length), 0, "the key must wait for an explicit user action");
    await page.locator("#jya-jpdb-connect-host").evaluate((host) => host.shadowRoot.querySelector("button").click());
    assert.equal(await page.evaluate(() => globalThis.__messages.length), 0, "a synthetic click must not capture the key");
    await page.locator("#jya-jpdb-connect-host").evaluate((host) => {
      const button = host.shadowRoot.querySelector("button");
      button.focus();
    });
    await page.keyboard.press("Enter");
    await page.waitForFunction(() => globalThis.__messages.length === 1);

    const result = await page.evaluate(() => ({
      hash: location.hash,
      message: globalThis.__messages[0],
      status: document.querySelector("#jya-jpdb-connect-host").shadowRoot.querySelector("p").textContent
    }));
    assert.equal(result.hash, "", "the one-time token should be removed from the address bar");
    assert.deepEqual(result.message, {type: "completeJpdbConnection", nonce, apiKey});
    assert.match(result.status, /^Connected\./);
    assert.equal(result.status.includes(apiKey), false, "status text must never reveal the API key");

    const unrelated = await context.newPage();
    await unrelated.goto("https://jpdb.io/settings");
    await unrelated.addScriptTag({path: path.join(extensionRoot, "jpdb-connect.js")});
    assert.equal(await unrelated.evaluate(() => globalThis.__messages.length), 0, "ordinary settings visits must not capture anything");
    console.log("jpdb connection browser tests passed");
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
