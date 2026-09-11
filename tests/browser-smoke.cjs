const assert = require("node:assert/strict");
const path = require("node:path");
const {chromium} = require("playwright");

const extensionRoot = path.resolve(__dirname, "..");

function chromeMockScript(options = {}) {
  return ({options}) => {
    const settings = {
      jpdbApiKey: "test-key",
      yomitanUrl: "http://127.0.0.1:19633",
      ankiUrl: "http://127.0.0.1:8765",
      includeMedia: false,
      maxYomitanEntries: 8,
      formatIndex: 0,
      filters: {
        skipParticles: true,
        skipVocalizations: true,
        skipSemanticGrammar: false,
        skipHonorifics: false,
        minimumOccurrences: 1
      },
      customExcludedIds: []
    };
    if (options.withoutJpdbKey) settings.jpdbApiKey = "";
    const state = {settings, ...(options.initialStorage || {})};
    const storageListeners = [];
    globalThis.__mockStorage = state;
    globalThis.__openedRequests = [];
    globalThis.chrome = {
      storage: {
        local: {
          async get(key) {
            if (typeof key === "string") return {[key]: state[key]};
            return {...state};
          },
          async set(value) {
            const changes = {};
            for (const [key, newValue] of Object.entries(value)) {
              changes[key] = {oldValue: state[key], newValue};
            }
            Object.assign(state, value);
            queueMicrotask(() => storageListeners.forEach((listener) => listener(changes, "local")));
          },
          async remove(key) { delete state[key]; }
        },
        onChanged: {addListener(listener) { storageListeners.push(listener); }}
      },
      runtime: {
          async sendMessage(message) {
            globalThis.__openedRequests.push(message);
            if (message.type === "getContentSettings") {
              return {ok: true, result: {
                hasJpdbApiKey: Boolean(state.settings.jpdbApiKey),
                includeMedia: Boolean(state.settings.includeMedia),
                formatIndex: Number(state.settings.formatIndex) || 0,
                filters: {...state.settings.filters},
                customExcludedIds: [...state.settings.customExcludedIds]
              }};
            }
            if (message.type === "saveContentPreferences") {
              const preferences = message.preferences || {};
              if (Object.prototype.hasOwnProperty.call(preferences, "includeMedia")) state.settings.includeMedia = Boolean(preferences.includeMedia);
              if (Object.prototype.hasOwnProperty.call(preferences, "formatIndex")) state.settings.formatIndex = Number(preferences.formatIndex) || 0;
              if (preferences.filters) state.settings.filters = {...state.settings.filters, ...preferences.filters};
              return {ok: true, result: true};
            }
            if (message.type === "getJpdbDeckWords") {
            return {ok: true, result: {words: [
              {jpdbId: "2028920", sid: "1", spelling: "は", reading: "は", meanings: ["topic marker"], occurrences: 19},
              {jpdbId: "1111010", sid: "1", spelling: "ふふ", reading: "ふふ", meanings: ["laugh"], occurrences: 2},
              {jpdbId: "1808780", sid: "1", spelling: "高木", reading: "たかぎ", meanings: ["Takagi"], occurrences: 34}
            ]}};
          }
          if (message.type === "getConnections") {
            const configured = options.connections || {};
            return {ok: true, result: {
              jpdb: configured.jpdb || (state.settings.jpdbApiKey ? {ok: true} : {ok: false, error: "API key required"}),
              yomitan: configured.yomitan || {ok: true, version: 1},
              anki: configured.anki || {ok: false, error: "Anki closed"},
              formats: configured.formats || [{name: "Expression", model: "Japanese", deck: "Mining", type: "term", fields: {Expression: {value: "{expression}"}, Meaning: {value: "{glossary}"}}}],
              formatError: configured.formatError || ""
            }};
          }
          return {ok: true, result: true};
        },
        connect() { throw new Error("Import port was not expected in this smoke test"); }
      }
    };
  };
}

async function injectExtension(page) {
  await page.addStyleTag({path: path.join(extensionRoot, "content.css")});
  await page.addScriptTag({path: path.join(extensionRoot, "core.js")});
  await page.addScriptTag({path: path.join(extensionRoot, "content.js")});
}

(async () => {
  const browser = await chromium.launch({
    headless: true,
    executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  });
  try {
    const animeContext = await browser.newContext();
    await animeContext.addInitScript(chromeMockScript(), {options: {}});
    await animeContext.route("https://jpdb.io/anime/758/karakai-jouzu-no-takagi-san", (route) => {
      const episodes = Array.from({length: 12}, (_, index) => {
        const number = index + 1;
        const subentry = number * 10;
        return `<div><h6>Episode ${number}</h6><div><form method="post" action="/add_prebuilt_deck"><input name="id" value="758"><input name="subentry" value="${subentry}"><button type="submit">Add deck</button></form><a class="outline v4" href="/anime/758/karakai-jouzu-no-takagi-san/${subentry}/episode-${number}/vocabulary-list">Vocabulary list</a></div></div>`;
      }).join("");
      return route.fulfill({status: 200, contentType: "text/html", body: `<!doctype html><html><body><main><h5>Karakai Jouzu no Takagi-san</h5>${episodes}</main></body></html>`});
    });
    await animeContext.route("https://jpdb.io/deck?id=321", (route) => route.fulfill({
      status: 200,
      contentType: "text/html",
      body: "<!doctype html><html><body><main><h5>Karakai Jouzu no Takagi-san - Episode 1</h5></main></body></html>"
    }));
    const animePage = await animeContext.newPage();
    await animePage.goto("https://jpdb.io/anime/758/karakai-jouzu-no-takagi-san", {waitUntil: "domcontentloaded", timeout: 20000});
    await animePage.evaluate(() => {
      document.addEventListener("submit", (event) => {
        event.preventDefault();
        const form = event.target;
        globalThis.__submittedDeckForm = {
          action: form.action,
          id: form.querySelector('[name="id"]')?.value,
          subentry: form.querySelector('[name="subentry"]')?.value
        };
      }, true);
    });
    await injectExtension(animePage);
    const buttons = animePage.locator(".jya-add-button");
    await buttons.first().waitFor();
    assert.ok(await buttons.count() >= 12, "episode buttons should be injected beside live jpdb vocabulary links");
    await buttons.first().dispatchEvent("click");
    await animePage.waitForTimeout(20);
    assert.equal(await animePage.evaluate(() => globalThis.__submittedDeckForm), undefined,
      "a script-generated episode click must not submit jpdb's form");
    assert.equal(await animePage.evaluate(() => sessionStorage.getItem("jpdbYomitanPendingImport")), null,
      "a script-generated episode click must not stage an import");
    await buttons.first().click();
    await animePage.waitForFunction(() => Boolean(globalThis.__submittedDeckForm));
    const submitted = await animePage.evaluate(() => ({
      form: globalThis.__submittedDeckForm,
      pending: JSON.parse(sessionStorage.getItem("jpdbYomitanPendingImport"))
    }));
    assert.equal(submitted.form.action.endsWith("/add_prebuilt_deck"), true);
    assert.equal(submitted.pending.animeId, "758");
    assert.ok(submitted.pending.episodeLabel.startsWith("Episode"));
    await animePage.goto("https://jpdb.io/deck?id=321");
    await injectExtension(animePage);
    assert.match(await animePage.locator(".jya-deck-button").textContent(), /Continue: review Episode 1/);
    await animePage.locator(".jya-deck-button").click();
    await animePage.locator(".jya-review-overlay").waitFor();
    assert.match(await animePage.locator(".jya-modal h2").textContent(), /Episode 1 vocabulary/);
    await animeContext.close();

    const deckContext = await browser.newContext();
    await deckContext.addInitScript(chromeMockScript(), {options: {}});
    await deckContext.route("https://jpdb.io/deck?id=123", (route) => route.fulfill({
      status: 200,
      contentType: "text/html",
      body: "<!doctype html><html><body><main><h5>Test Episode</h5><p>Deck page</p></main></body></html>"
    }));
    const deckPage = await deckContext.newPage();
    await deckPage.goto("https://jpdb.io/deck?id=123");
    await injectExtension(deckPage);
    await deckPage.locator(".jya-deck-button").click();
    await deckPage.locator(".jya-review-overlay").waitFor();
    assert.equal(await deckPage.locator(".jya-word-row").count(), 3);
    assert.match(await deckPage.locator(".jya-count").textContent(), /1 included · 2 skipped/);
    assert.equal(await deckPage.getByRole("button", {name: "Export as APKG"}).isDisabled(), true);
    assert.equal(await deckPage.locator(".jya-anki-offline-message").isVisible(), true);
    assert.equal(await deckPage.locator(".jya-anki-offline-message").textContent(), "Your Anki is offline. Please open Anki and refresh this page.");
    await deckPage.getByText("Other exports", {exact: true}).click();
    assert.equal(await deckPage.getByRole("button", {name: "Anki .txt"}).isEnabled(), true);
    const privilegedRequestsBefore = await deckPage.evaluate(() => globalThis.__openedRequests.length);
    await deckPage.getByRole("button", {name: "Copy for Yomitan"}).dispatchEvent("click");
    await deckPage.getByRole("button", {name: "Anki .txt"}).dispatchEvent("click");
    await deckPage.getByRole("button", {name: "Export as APKG"}).evaluate((button) => {
      button.disabled = false;
      button.dispatchEvent(new MouseEvent("click", {bubbles: true}));
    });
    await deckPage.waitForTimeout(20);
    assert.equal(await deckPage.evaluate(() => globalThis.__openedRequests.length), privilegedRequestsBefore,
      "script-generated clicks must not copy, export, import, or open Yomitan");
    await deckPage.locator(".jya-filter-grid label").first().click();
    assert.match(await deckPage.locator(".jya-count").textContent(), /2 included · 1 skipped/);
    await deckPage.screenshot({path: "/tmp/jpdb-yomitan-review-smoke.png", fullPage: true});
    await deckContext.close();

    const setupContext = await browser.newContext({viewport: {width: 860, height: 1000}});
    await setupContext.addInitScript(chromeMockScript(), {options: {}});
    const setupPage = await setupContext.newPage();
    await setupPage.goto(`file://${path.join(extensionRoot, "onboarding.html")}`);
    await setupPage.locator("#jpdb-api-key").waitFor({state: "attached"});
    assert.equal(await setupPage.locator("#skip-particles").isChecked(), true);
    assert.equal(await setupPage.locator("#skip-semantic-grammar").isChecked(), false);
    await setupPage.waitForFunction(() =>
      document.querySelectorAll("#connection-status .connection-row.ok").length === 2 &&
      document.querySelectorAll("#connection-status .connection-row.warn").length === 1
    );
    assert.equal(await setupPage.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, "setup must not overflow its desktop page");
    assert.match(await setupPage.locator("#overall-status").textContent(), /export is ready/i);
    assert.equal(await setupPage.locator("#ready-panel").isVisible(), true);
    assert.equal(await setupPage.locator("#anki-actions").isVisible(), true);
    await setupPage.locator("#cleanup-settings > summary").click();
    await setupPage.screenshot({path: "/tmp/jpdb-yomitan-onboarding-desktop-ready.png", fullPage: true});
    await setupPage.locator("#skip-semantic-grammar").check();
    await setupPage.waitForFunction(() => globalThis.__mockStorage.settings.filters.skipSemanticGrammar === true);
    await setupPage.locator("#minimum-occurrences").fill("200");
    await setupPage.locator("#minimum-occurrences").dispatchEvent("change");
    await setupPage.waitForFunction(() => globalThis.__mockStorage.settings.filters.minimumOccurrences === 99);
    assert.equal(await setupPage.locator("#minimum-occurrences").inputValue(), "99");
    const unlabeledInputs = await setupPage.locator("input").evaluateAll((inputs) =>
      inputs.filter((input) => !input.labels?.length && !input.getAttribute("aria-label") && !input.getAttribute("aria-labelledby"))
        .map((input) => input.id)
    );
    assert.deepEqual(unlabeledInputs, [], "every setup control should have an accessible label");
    await setupPage.locator("#test-connections").click();
    await setupPage.waitForFunction(() => document.querySelector("#test-connections").textContent === "Check again");
    await setupPage.screenshot({path: "/tmp/jpdb-yomitan-onboarding-smoke.png", fullPage: true});
    await setupContext.close();

    const firstRunContext = await browser.newContext({viewport: {width: 380, height: 720}});
    await firstRunContext.addInitScript(chromeMockScript(), {options: {withoutJpdbKey: true}});
    const firstRunPage = await firstRunContext.newPage();
    await firstRunPage.goto(`file://${path.join(extensionRoot, "onboarding.html")}`);
    await firstRunPage.waitForFunction(() => document.querySelector("#jpdb-row")?.classList.contains("bad"));
    assert.equal(await firstRunPage.locator("#connect-jpdb").isVisible(), true);
    await firstRunPage.screenshot({path: "/tmp/jpdb-yomitan-first-run-380.png", fullPage: true});
    await firstRunPage.keyboard.press("Tab");
    assert.equal(await firstRunPage.evaluate(() => document.activeElement?.id), "test-connections");
    assert.notEqual(await firstRunPage.locator("#test-connections").evaluate((element) => getComputedStyle(element).outlineStyle), "none");
    await firstRunPage.locator("#show-manual-key").click();
    assert.equal(await firstRunPage.locator("#manual-settings").evaluate((element) => element.open), true);
    assert.equal(await firstRunPage.evaluate(() => document.activeElement?.id), "jpdb-api-key");
    await firstRunPage.locator("#manual-settings").evaluate((element) => { element.open = false; });
    await firstRunPage.locator("#connect-jpdb").click();
    await firstRunPage.waitForFunction(() => globalThis.__openedRequests.some((request) => request.type === "beginJpdbConnection"));
    await firstRunPage.waitForFunction(() => !document.querySelector("#connect-jpdb").disabled);
    assert.equal(await firstRunPage.locator("#connect-jpdb").textContent(), "Connect signed-in account", "jpdb connect should remain retryable if its tab is closed");
    assert.equal(await firstRunPage.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, "setup must not overflow a narrow extension popup");
    await firstRunPage.screenshot({path: "/tmp/jpdb-yomitan-first-run-smoke.png", fullPage: true});
    await firstRunPage.evaluate(() => chrome.storage.local.set({
      settings: {...globalThis.__mockStorage.settings, jpdbApiKey: "d".repeat(32)}
    }));
    await firstRunPage.waitForFunction(() => document.querySelector("#jpdb-row")?.classList.contains("ok"));
    assert.equal(await firstRunPage.locator("#connect-jpdb").isVisible(), false, "external key capture should refresh setup automatically");
    await firstRunContext.close();

    const apiSetupContext = await browser.newContext({viewport: {width: 380, height: 720}});
    await apiSetupContext.addInitScript(chromeMockScript(), {options: {connections: {
      jpdb: {ok: true}, yomitan: {ok: false, error: "Bridge unavailable"}, anki: {ok: true, version: 6}, formats: []
    }}});
    const apiSetupPage = await apiSetupContext.newPage();
    await apiSetupPage.goto(`file://${path.join(extensionRoot, "onboarding.html")}`);
    await apiSetupPage.locator("#open-yomitan-api").waitFor({state: "visible"});
    await apiSetupPage.locator("#open-yomitan-api").click();
    await apiSetupPage.waitForFunction(() => globalThis.__openedRequests.some((request) => request.type === "openYomitanApiSettings"));
    await apiSetupContext.close();

    const formatSetupContext = await browser.newContext({viewport: {width: 860, height: 900}});
    await formatSetupContext.addInitScript(chromeMockScript(), {options: {connections: {
      jpdb: {ok: true}, yomitan: {ok: true, version: 1}, anki: {ok: true, version: 6}, formats: [], formatError: "No usable format"
    }}});
    const formatSetupPage = await formatSetupContext.newPage();
    await formatSetupPage.goto(`file://${path.join(extensionRoot, "onboarding.html")}`);
    await formatSetupPage.locator("#open-yomitan-formats").waitFor({state: "visible"});
    assert.match(await formatSetupPage.locator("#yomitan-detail").textContent(), /No usable format/);
    await formatSetupPage.locator("#open-yomitan-formats").click();
    await formatSetupPage.waitForFunction(() => globalThis.__openedRequests.some((request) => request.type === "openYomitanSettings"));
    await formatSetupContext.close();

    console.log("Browser smoke tests passed");
  } finally {
    await browser.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
