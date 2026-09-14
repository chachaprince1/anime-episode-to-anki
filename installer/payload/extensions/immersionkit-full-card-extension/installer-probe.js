// Used only while the installer window is open. It does not affect mining.
const installerCallback = "http://127.0.0.1:19634/extension-loaded?extension=immersionkit";
async function announceInstallerLoad() {
  try { await fetch(installerCallback, {method: "POST", cache: "no-store"}); } catch (_) {}
}
chrome.runtime.onInstalled.addListener(() => { void announceInstallerLoad(); });
chrome.runtime.onStartup.addListener(() => { void announceInstallerLoad(); });
void announceInstallerLoad();
