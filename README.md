# Website → Yomitan → Anki

This Chrome extension lets you turn vocabulary from anime episodes on **the website introduced in class** into Anki cards using **your Yomitan dictionaries and card settings**.

The basic process is:

**Choose an episode → review the vocabulary → add the cards to Anki**

The extension automatically removes common low-value items, such as standalone particles and fillers, before you review the list. You can add any of them back if you want.

## What You Need

Before using the extension, you will need:

* A free account on **the website introduced in class**
* **Yomitan** installed in Chrome
* **Anki Desktop**
* The **AnkiConnect** add-on for Anki
* The included **Yomitan API helper**

Your existing Yomitan dictionaries and card formats are used to create the cards, so you can keep the definitions, readings, pitch accent, frequency information, and other features you already use in Yomitan.

## Install the Extension

These steps assume Yomitan and Anki are already installed and configured.
Do not click individual `.js`, `.html`, or `.json` files on GitHub. Those files
work together as one Chrome extension.

### Easier student setup

If you are distributing both this extension and ImmersionKit Full Card Miner,
download the [Student Setup package](student-setup-installer.zip). Unzip it,
then double-click `setup-macos.command` on macOS or `setup-windows.bat` on
Windows. The launcher copies both extensions to a permanent per-user folder,
opens Chrome's extensions page, opens the exact folder to select, copies its
path to the clipboard, and opens a setup wizard with connection checks.

Chrome still requires two final clicks for local extensions: turn on
**Developer mode**, click **Load unpacked**, and select each extension folder.
The wizard then points to the included Yomitan API helper installer. This is
the shortest supported setup without publishing the extensions in the Chrome
Web Store.

### 1. Download the extension from GitHub

1. Open the [Anime Episode to Anki GitHub page](https://github.com/chachaprince1/anime-episode-to-anki).
2. Near the upper-right part of the file list, click the green **Code** button.
3. In the menu that opens, click **Download ZIP**.
4. Wait for the download to finish. The file normally appears in your
   **Downloads** folder and is named `anime-episode-to-anki-main.zip`.

### 2. Unzip the download

#### macOS

1. Open **Finder**.
2. Click **Downloads** in the left sidebar.
3. Find `anime-episode-to-anki-main.zip`.
4. Double-click the ZIP file once. Finder creates a normal folder named
   `anime-episode-to-anki-main` beside it.
5. Drag that new folder somewhere permanent, such as **Documents**. Do not
   leave it in the Trash and do not delete it after installing the extension.

#### Windows

1. Open **File Explorer**.
2. Click **Downloads** in the left sidebar.
3. Right-click `anime-episode-to-anki-main.zip`.
4. Click **Extract All…**.
5. Leave **Show extracted files when complete** checked, then click
   **Extract**.
6. Move the extracted `anime-episode-to-anki-main` folder somewhere permanent,
   such as **Documents**. Do not delete it after installing the extension.

### 3. Load the folder into Chrome

1. Open Google Chrome.
2. Click the address bar at the top of Chrome.
3. Type `chrome://extensions` and press **Return** on macOS or **Enter** on
   Windows.
4. Turn on **Developer mode** using the switch in the upper-right corner.
5. Click **Load unpacked** in the upper-left corner.
6. In the folder window, select the extracted
   `anime-episode-to-anki-main` folder. Select the folder itself, not the ZIP
   file and not one of the files inside it.
7. Click **Select** or **Open**. If Chrome says it cannot find a manifest,
   you selected the wrong folder: go back and select the folder that directly
   contains `manifest.json`.
8. Chrome should add a card named **jpd. → Yomitan → Anki** to the Extensions
   page, and the extension's setup page should open automatically.

Keep the extracted folder on your computer. Chrome loads the extension from
that exact location every time it starts.

## Connect Your Account

1. Sign up / sign in to your free account (the anime website) in the same Chrome profile where you
   installed the extension.
2. Return to the extension's setup tab.
3. Find the **jpd..** row. It should say **Action needed**.
4. Click **Connect signed-in account**.
5. Chrome opens the website's settings page. Scroll to the API-key section near the
   bottom of that page.
6. Click the extension's **Use this API key** button. Do not post or send the
   key to anyone.
7. Wait for the message confirming that the key was verified and saved.
8. Return to the extension setup tab. The jpd. row should now say
   **Connected**. If it does not update, click **Check again** at the top of
   the setup page.

## Install the Required Yomitan API Helper

Yomitan itself may already be fully configured, but this extension also needs
the included local API helper so it can ask Yomitan to build cards.

### On Mac

Find this file inside the extension folder:

`install-yomitan-api-macos.command`

Double-click it.

If macOS blocks it:

1. Right-click the file.
2. Choose **Open**.
3. Choose **Open** again.

The installer should open Yomitan's settings when it finishes.

Then:

2. Open **General**.
3. Turn on **Enable Yomitan API**.
4. Accept Chrome's permission request if one appears.

You normally do not need to change anything else.

### On Windows

1. Open the extracted `anime-episode-to-anki-main` folder in File Explorer.
2. Find `install-yomitan-api-windows.bat`.
3. Double-click the file.
4. If Windows displays a protection warning, click **More info**, confirm the
   filename, and click **Run anyway**.
5. Keep the black installer window open until it says it has finished.
6. In Chrome, click the puzzle-piece **Extensions** icon, find **Yomitan**, and
   open its settings.
8. Open **General**, turn on **Enable Yomitan API**, and accept Chrome's
   permission prompt if one appears.

After either installer finishes, return to the extension setup page and click
**Check again**. Yomitan should show **Connected**.

## Set Up Anki

1. Open **Anki Desktop** and leave it running.
2. On the extension setup page, click **Check again**.
3. Confirm that AnkiConnect shows **Connected**. If it does not, confirm that
   your existing AnkiConnect add-on is enabled and restart Anki.

That is it. AnkiConnect's normal settings work with the extension.

The setup page automatically checks whether the website, Yomitan, and Anki are ready.

## Add an Episode to Anki

On an anime page, you will see a new **Add to Anki** button beside each
episode.

### 1. Choose an Episode

1. Open Anki Desktop and leave it running during the export.
2. In Chrome, open the website's anime difficulty list and open an anime's detail
   page.
3. Find the episode you want and click **Add to Anki** beside that episode.
4. The website adds the episode to your account and opens its deck page.
5. On that deck page, click **Continue: review Episode … for Anki**.
6. If you opened a deck directly instead, click
   **Add deck to Anki with Yomitan**.
7. Wait while the extension retrieves the vocabulary. The review window opens
   when it is ready.

### 2. Review the Vocabulary

1. Read the count in the upper-right corner of the review window. It shows how
   many words are included and skipped.
2. Under **Skip word sets**, check every category you want removed from the
   export. 
5. Under **Skip duplicates**, choose either the narrower same-j...-card check,
   the broader same-word check, or neither. 
6. Confirm that the included/skipped count changes when you change a filter.

### 3. Add the Cards

1. Click **Export as APKG**.
2. Leave Chrome and Anki open while Yomitan creates every selected card. The
   progress display shows the word currently being processed.
3. Wait until the button changes to **View Export**.
4. The cards have been added to the destination deck in Anki, and Chrome has
   also downloaded an `.apkg` copy.
5. Click **View Export** to open the download's location on your computer.


## Updating the Extension

When you receive a new version:

1. Replace the old extension folder with the new one.
2. Open `chrome://extensions`.
3. Press the **Reload** button for the extension.

Your normal setup should remain the same.
