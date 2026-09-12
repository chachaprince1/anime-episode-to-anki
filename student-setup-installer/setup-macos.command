#!/bin/bash
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/Application Support/Anime Study Tools/Extensions"
YOMITAN_HOST="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/yomitan_api.json"
fail() { printf 'Setup stopped: %s\n' "$1" >&2; read -r -p 'Press Return to close.' || true; exit 1; }
for ext in anime-episode-to-anki immersionkit-full-card-extension; do
  manifest="$BASE/payload/$ext/manifest.json"
  [[ -d "$BASE/payload/$ext" && -f "$manifest" ]] || fail "Missing payload for $ext. Download a fresh installer."
  plutil -convert json -o /dev/null "$manifest" >/dev/null 2>&1 || fail "Invalid manifest for $ext. Download a fresh installer."
done
mkdir -p "$DEST"
for ext in anime-episode-to-anki immersionkit-full-card-extension; do
  stage="$DEST/.${ext}.new.$$"; backup="$DEST/.${ext}.backup.$(date +%Y%m%d-%H%M%S)"
  rm -rf "$stage"; ditto "$BASE/payload/$ext" "$stage" || fail "Could not copy $ext."
  plutil -convert json -o /dev/null "$stage/manifest.json" >/dev/null 2>&1 || fail "Copied manifest for $ext is invalid."
  [[ -d "$DEST/$ext" ]] && mv "$DEST/$ext" "$backup"
  mv "$stage" "$DEST/$ext"
done
if [[ ! -f "$YOMITAN_HOST" ]]; then open "$DEST/anime-episode-to-anki/install-yomitan-api-macos.command" || true; fi
open -a "Google Chrome" "chrome://extensions/" || true
open -R "$DEST/anime-episode-to-anki" || true
printf '%s\n' "$DEST/anime-episode-to-anki" | pbcopy || true
yomitan=offline; anki=offline
curl --silent --show-error --fail --max-time 2 -X POST -H 'Content-Type: application/json' -d '{}' http://127.0.0.1:19633/serverVersion | grep -q '[{[]' && yomitan=ok || true
curl --silent --show-error --fail --max-time 2 -X POST -H 'Content-Type: application/json' -d '{"action":"version","version":6}' http://127.0.0.1:8765 | grep -q 'result' && anki=ok || true
DEST_QUERY=${DEST//%/%25}; DEST_QUERY=${DEST_QUERY// /%20}; DEST_QUERY=${DEST_QUERY//#/%23}; DEST_QUERY=${DEST_QUERY//\?/%3F}; DEST_QUERY=${DEST_QUERY//&/%26}; DEST_QUERY=${DEST_QUERY//+/%2B}; DEST_QUERY=${DEST_QUERY//=/%3D}
BASE_QUERY=${BASE//%/%25}; BASE_QUERY=${BASE_QUERY// /%20}; BASE_QUERY=${BASE_QUERY//#/%23}; BASE_QUERY=${BASE_QUERY//\?/%3F}; BASE_QUERY=${BASE_QUERY//&/%26}; BASE_QUERY=${BASE_QUERY//+/%2B}; BASE_QUERY=${BASE_QUERY//=/%3D}
open "file://$BASE_QUERY/setup.html?dest=$DEST_QUERY&yomitan=$yomitan&anki=$anki"
