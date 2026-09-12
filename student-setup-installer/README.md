# Anime Study Tools — student setup

## 1. Download and open the package

On GitHub, click **Code → Download ZIP**. When it finishes:

- **Mac:** double-click the ZIP to extract it. Open the extracted folder. If macOS blocks the launcher, right-click `setup-macos.command`, choose **Open**, then choose **Open** again.
- **Windows:** right-click the ZIP, choose **Extract All**, and open the extracted folder. If Windows shows **More info**, choose **Run anyway** for the launcher.

Double-click `setup-macos.command` on Mac or `setup-windows.bat` on Windows. The launcher copies both extensions to a stable user folder, opens Chrome, opens the folder, and checks Anki/Yomitan.

## 2. Load the two extensions

In Chrome, turn on **Developer mode** in the upper-right corner, then click **Load unpacked**. Select these child folders one at a time, not the parent folder: `anime-episode-to-anki`, then `immersionkit-full-card-extension`.

On Mac, press **Command-Shift-G** in the folder picker and use the path copied by the launcher. On Windows, press **Ctrl-L** in File Explorer and use the path shown by the launcher. Confirm that both names appear at `chrome://extensions`.

## 3. Finish Yomitan and Anki setup

Open the `anime-episode-to-anki` folder inside the staged Extensions folder. On Mac, double-click `install-yomitan-api-macos.command`. On Windows, double-click `install-yomitan-api-windows.bat`. If your computer asks whether to open or run the helper, choose **Open** or **Run**.

In Yomitan, open settings, enable **Advanced**, then enable **Yomitan API**. Keep Anki open with AnkiConnect installed. Return to the setup page and confirm both connections show online.

If a connection is offline or an extension is missing, start Anki/Yomitan and run the platform launcher again. It is safe for repairs and updates.
