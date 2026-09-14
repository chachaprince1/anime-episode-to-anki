#!/bin/bash
# Build-time only. The resulting binary contains a private Python runtime;
# students never need Python, Homebrew, or a helper script.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/helper/yomitan_api.py"
EXPECTED="ade5a1824be628a041249b993a88c29a9efec7de1fad763a590b0995ec55cbfc"
ACTUAL="$(shasum -a 256 "$SOURCE" | awk '{print $1}')"
[[ "$ACTUAL" == "$EXPECTED" ]] || { echo "Pinned Yomitan helper checksum did not match." >&2; exit 1; }
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/anime-study-tools-helper.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
python3 -m venv "$BUILD/venv"
"$BUILD/venv/bin/python" -m pip install --disable-pip-version-check 'pyinstaller==6.11.1'
cp "$SOURCE" "$BUILD/yomitan_api.py"
perl -0pi -e 's{script_path = os\.path\.realpath\(os\.path\.dirname\(__file__\)\)}{script_path = (os.path.dirname(os.path.abspath(sys.executable)) if getattr(sys, "frozen", False) else os.path.realpath(os.path.dirname(__file__)))}' "$BUILD/yomitan_api.py"
"$BUILD/venv/bin/pyinstaller" --noconfirm --clean --onefile --target-architecture universal2 \
  --name yomitan-api-host --distpath "$BUILD/dist" --workpath "$BUILD/work" --specpath "$BUILD/spec" "$BUILD/yomitan_api.py"
mkdir -p "$ROOT/macos/Resources"
cp "$BUILD/dist/yomitan-api-host" "$ROOT/macos/Resources/yomitan-api-host"
file "$ROOT/macos/Resources/yomitan-api-host"
