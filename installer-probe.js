"use strict";

// Used only while the installer window is open, to confirm that Chrome loaded
// this unpacked extension. Failure is deliberately silent: normal extension
// use never depends on the installer being present.
const installerCallback = "http://127.0.0.1:19634/extension-loaded?extension=anime&onboarding=" + encodeURIComponent(chrome.runtime.getURL("onboarding.html"));
async function announceInstallerLoad() {
  try { await fetch(installerCallback, {method: "POST", cache: "no-store"}); } catch (_) {}
}
async function announceJpdbConnected() {
  try { await fetch("http://127.0.0.1:19634/jpdb-connected?extension=anime", {method: "POST", cache: "no-store"}); } catch (_) {}
}
globalThis.JYAInstallerProbe = Object.freeze({announceJpdbConnected});
chrome.runtime.onInstalled.addListener(() => { void announceInstallerLoad(); });
chrome.runtime.onStartup.addListener(() => { void announceInstallerLoad(); });
void announceInstallerLoad();
