#!/bin/bash
set -e
BASE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/Application Support/Anime Study Tools/Extensions"
mkdir -p "$DEST"
for ext in anime-episode-to-anki immersionkit-full-card-extension; do
  if [ -d "$BASE/payload/$ext" ]; then
    rm -rf "$DEST/$ext"
    ditto "$BASE/payload/$ext" "$DEST/$ext"
  fi
done
open -a "Google Chrome" "chrome://extensions/" || true
open -R "$DEST" || true
printf '%s\n' "$DEST" | pbcopy || true
YOMITAN=offline; ANKI=offline; nc -z 127.0.0.1 19633 2>/dev/null && YOMITAN=ok || true; nc -z 127.0.0.1 8765 2>/dev/null && ANKI=ok || true
# The standard macOS install path contains spaces. Encode those without relying
# on Python (which is not guaranteed to be installed on current macOS releases).
DEST_QUERY=${DEST//%/%25}
DEST_QUERY=${DEST_QUERY// /%20}
DEST_QUERY=${DEST_QUERY//#/%23}
DEST_QUERY=${DEST_QUERY//\?/%3F}
BASE_QUERY=${BASE//%/%25}; BASE_QUERY=${BASE_QUERY// /%20}; BASE_QUERY=${BASE_QUERY//#/%23}
open "file://$BASE_QUERY/setup.html?dest=$DEST_QUERY&yomitan=$YOMITAN&anki=$ANKI"
