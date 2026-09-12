#!/bin/bash
# Installs the official Yomitan API native helper for the current macOS user.
# It does not require administrator privileges.

set -euo pipefail

readonly HELPER_REVISION="d6a79d184062a048549fa8e82e3a880e2c2783e7"
readonly HELPER_SHA256="ade5a1824be628a041249b993a88c29a9efec7de1fad763a590b0995ec55cbfc"
readonly HELPER_URL="https://raw.githubusercontent.com/yomidevs/yomitan-api/${HELPER_REVISION}/yomitan_api.py"
readonly YOMITAN_EXTENSION_ID="likgccmbimhjbgkjambclfkhldnlhbnn"
readonly YOMITAN_SETTINGS_URL="chrome-extension://${YOMITAN_EXTENSION_ID}/settings.html#general"

readonly USER_LIBRARY="${HOME}/Library"
readonly HELPER_DIRECTORY="${USER_LIBRARY}/Application Support/Yomitan API"
readonly HELPER_PATH="${HELPER_DIRECTORY}/yomitan_api.py"
readonly HOST_WRAPPER_PATH="${HELPER_DIRECTORY}/yomitan-api-host"
readonly NATIVE_HOST_DIRECTORY="${USER_LIBRARY}/Application Support/Google/Chrome/NativeMessagingHosts"
readonly NATIVE_HOST_PATH="${NATIVE_HOST_DIRECTORY}/yomitan_api.json"

cleanup() {
    if [[ -n "${temporary_file:-}" && -f "${temporary_file}" ]]; then
        rm -f "${temporary_file}"
    fi
}
trap cleanup EXIT

fail() {
    printf '\nInstallation stopped: %s\n' "$1" >&2
    exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl is required but was not found."
command -v shasum >/dev/null 2>&1 || fail "shasum is required but was not found."
PYTHON_EXECUTABLE="$(command -v python3 || true)"
if [[ -z "${PYTHON_EXECUTABLE}" || "${PYTHON_EXECUTABLE}" != /* || ! -x "${PYTHON_EXECUTABLE}" ]]; then
    if command -v brew >/dev/null 2>&1; then
        printf 'Python 3 was not found. Installing it with Homebrew…\n'
        brew install python || fail "Could not install Python 3 with Homebrew."
        PYTHON_EXECUTABLE="$(command -v python3 || true)"
    else
        printf 'Python 3 is needed once for the Yomitan helper. Opening the official installer…\n'
        open "https://www.python.org/downloads/macos/" || true
        fail "Finish the official Python installer, then run this helper again."
    fi
fi
[[ -n "${PYTHON_EXECUTABLE}" && "${PYTHON_EXECUTABLE}" == /* && -x "${PYTHON_EXECUTABLE}" ]] \
    || fail "Python 3 could not be found after installation. Restart Terminal, then run this helper again."
readonly PYTHON_EXECUTABLE

printf 'Installing the Yomitan API helper for this macOS user…\n'
temporary_file="$(mktemp "${TMPDIR:-/tmp}/yomitan-api.XXXXXX")"

curl --fail --location --proto '=https' --tlsv1.2 --output "${temporary_file}" "${HELPER_URL}" \
    || fail "Could not download the official Yomitan API helper."

actual_sha256="$(shasum -a 256 "${temporary_file}" | awk '{print $1}')"
[[ "${actual_sha256}" == "${HELPER_SHA256}" ]] \
    || fail "Checksum verification failed. Nothing was installed."

mkdir -p "${HELPER_DIRECTORY}" "${NATIVE_HOST_DIRECTORY}"
install -m 644 "${temporary_file}" "${HELPER_PATH}"

if [[ -f "${NATIVE_HOST_PATH}" ]]; then
    backup_path="${NATIVE_HOST_PATH}.backup.$(date +%Y%m%d-%H%M%S)"
    cp -p "${NATIVE_HOST_PATH}" "${backup_path}"
    printf 'Backed up existing native host manifest: %s\n' "${backup_path}"
fi

"${PYTHON_EXECUTABLE}" - "${PYTHON_EXECUTABLE}" "${HELPER_PATH}" "${HOST_WRAPPER_PATH}" "${NATIVE_HOST_PATH}" "${YOMITAN_EXTENSION_ID}" <<'PY'
import json
import pathlib
import shlex
import sys

python_path, helper_path, wrapper_path, manifest_path, extension_id = sys.argv[1:]
wrapper = pathlib.Path(wrapper_path)
wrapper.write_text(
    "#!/bin/bash\nexec " + shlex.quote(python_path) + " -u " + shlex.quote(helper_path) + "\n",
    encoding="utf-8",
)
manifest = {
    "name": "yomitan_api",
    "description": "Yomitan API native messaging host",
    "path": wrapper_path,
    "type": "stdio",
    "allowed_origins": [f"chrome-extension://{extension_id}/"],
}
pathlib.Path(manifest_path).write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY
chmod 755 "${HOST_WRAPPER_PATH}"
chmod 644 "${NATIVE_HOST_PATH}"

printf '\nInstalled successfully.\n\n'
if command -v open >/dev/null 2>&1 && open -a "Google Chrome" "${YOMITAN_SETTINGS_URL}" >/dev/null 2>&1; then
    printf 'Opened Yomitan General settings in Google Chrome.\n\n'
else
    printf 'Could not open Yomitan settings automatically. Open this address in Google Chrome:\n'
    printf '  %s\n\n' "${YOMITAN_SETTINGS_URL}"
fi

printf 'Next steps:\n'
printf '  1. In Yomitan, turn on Advanced, then enable “Enable Yomitan API”.\n'
printf '  2. Leave its URL at http://127.0.0.1:19633.\n'
printf '  3. Start Anki Desktop with AnkiConnect enabled before direct imports.\n'
printf '  4. Return to the extension setup; it checks the connections automatically.\n\n'
printf 'If Yomitan is not detected, fully quit and reopen Chrome, then try again.\n\n'
printf 'Installed helper: %s\n' "${HELPER_PATH}"
printf 'Native host launcher: %s\n' "${HOST_WRAPPER_PATH}"
printf 'Chrome host manifest: %s\n' "${NATIVE_HOST_PATH}"
printf '\nPress Return to close this window.\n'
read -r || true
