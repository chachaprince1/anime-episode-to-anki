# Bundled Yomitan API helper

The installers freeze the official `yomitan_api.py` helper with PyInstaller at
build time. The generated host contains its own Python runtime, so students do
not install or run Python.

* Upstream: <https://github.com/yomidevs/yomitan-api>
* Pinned revision: `d6a79d184062a048549fa8e82e3a880e2c2783e7`
* Source file: `yomitan_api.py`
* SHA-256: `ade5a1824be628a041249b993a88c29a9efec7de1fad763a590b0995ec55cbfc`
* License: GNU GPL version 3, reproduced in `LICENSE.yomitan-api.txt`.

The only build-time change is a frozen-runtime path adjustment: `.crowbar` and
`error.log` are placed beside the installed host executable rather than in a
temporary PyInstaller extraction directory. The original source and this build
adjustment are included in this repository.
