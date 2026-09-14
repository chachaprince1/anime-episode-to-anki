#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
for extension in anime-episode-to-anki immersionkit-full-card-extension; do
  plutil -convert json -o /dev/null "$ROOT/installer/payload/extensions/$extension/manifest.json"
done
[[ "$(jq -r '.name' "$ROOT/installer/payload/extensions/anime-episode-to-anki/manifest.json")" == "jpdb → Yomitan → Anki" ]]
[[ "$(jq -r '.background.service_worker' "$ROOT/installer/payload/extensions/anime-episode-to-anki/manifest.json")" == "background.js" ]]
[[ "$(jq -r '.name' "$ROOT/installer/payload/extensions/immersionkit-full-card-extension/manifest.json")" == "ImmersionKit Full Card Miner" ]]
[[ "$(jq -r '.background.service_worker' "$ROOT/installer/payload/extensions/immersionkit-full-card-extension/manifest.json")" == "background-v192.js" ]]
[[ "$(jq -r '.background.type' "$ROOT/installer/payload/extensions/immersionkit-full-card-extension/manifest.json")" == "module" ]]
grep -q 'extension-loaded?extension=anime' "$ROOT/installer/payload/extensions/anime-episode-to-anki/installer-probe.js"
grep -q 'extension-loaded?extension=immersionkit' "$ROOT/installer/payload/extensions/immersionkit-full-card-extension/installer-probe.js"
grep -q 'importScripts("core.js", "jpdb-connect-background.js", "installer-probe.js")' "$ROOT/installer/payload/extensions/anime-episode-to-anki/background.js"
grep -q 'import "./installer-probe.js"' "$ROOT/installer/payload/extensions/immersionkit-full-card-extension/background-v192.js"
grep -q '19634' "$ROOT/installer/payload/extensions/immersionkit-full-card-extension/manifest.json"
[[ "$(shasum -a 256 "$ROOT/installer/helper/yomitan_api.py" | awk '{print $1}')" == "ade5a1824be628a041249b993a88c29a9efec7de1fad763a590b0995ec55cbfc" ]]
test -s "$ROOT/installer/helper/LICENSE.yomitan-api.txt"
test -x "$ROOT/installer/macos/Resources/yomitan-api-host"
file "$ROOT/installer/macos/Resources/yomitan-api-host" | grep -q 'universal binary'
echo "installer payload and private macOS runtime checks passed"
