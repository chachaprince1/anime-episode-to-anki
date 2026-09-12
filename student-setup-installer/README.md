# Anime Study Tools Student Setup

This package stages both extensions: `anime-episode-to-anki` and `immersionkit-full-card-extension`.

Chrome requires the student to perform the final **Developer mode → Load unpacked** step. The launchers copy the extensions into stable per-user folders, open Chrome’s extensions page, reveal the folder, copy its path, and open the wizard.

On macOS, double-click `setup-macos.command`. On Windows, double-click `setup-windows.bat`. Each launcher stages the extensions, opens Chrome's extensions page, reveals the staged folder, copies its path, checks ports 19633 and 8765, and opens the wizard with the results. Then enable Developer mode, click Load unpacked, and select each extension folder (not the parent folder). The wizard's links open Chrome/Yomitan/Anki pages; it does not show controls that depend on a background bridge. Run the launcher again for repairs or updates.
