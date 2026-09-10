# Website → Yomitan → Anki

This Chrome extension lets you turn vocabulary from anime episodes on **the website** into Anki cards using **your Yomitan dictionaries and card settings**.

The basic process is:

**Choose an episode → review the vocabulary → add the cards to Anki**

The extension automatically removes common low-value items, such as standalone particles and fillers, before you review the list. You can add any of them back if you want.

## What You Need

Before using the extension, you will need:

* A free account on **the website**
* **Yomitan** installed in Chrome
* **Anki Desktop**
* The **AnkiConnect** add-on for Anki
* The included **Yomitan API helper**

Your existing Yomitan dictionaries and card formats are used to create the cards, so you can keep the definitions, readings, pitch accent, frequency information, and other features you already use in Yomitan.

## Install the Extension

1. Unzip the extension if necessary.
2. In Chrome, open `chrome://extensions`.
3. Turn on **Developer mode**.
4. Click **Load unpacked**.
5. Select the extension folder.

The setup page should open automatically.

Keep the extension folder on your computer after installing it.

## Connect Your Account

On the setup page, click:

**Connect signed-in account**

The extension will guide you through connecting your account on the website.

You will need to be signed into your free account.

If the setup page shows **Action needed**, follow the instructions for that item. Everything else is handled automatically.

## Set Up Yomitan

The extension needs permission to use Yomitan when creating cards.

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

1. Turn on **Advanced** in Yomitan if it is not already on.
2. Open **General**.
3. Turn on **Enable Yomitan API**.
4. Accept Chrome's permission request if one appears.

You normally do not need to change anything else.

## Set Up Anki

1. Install **AnkiConnect** if you do not already have it.
2. Open **Anki Desktop**.

That is it. AnkiConnect's normal settings work with the extension.

The setup page automatically checks whether the website, Yomitan, and Anki are ready.

## Add an Episode to Anki

On an anime page, you will see a new **Add to Anki** button beside each episode.

### 1. Choose an Episode

Click **Add to Anki**.

The episode will be added to your account and opened.

Click **Continue** when prompted.

If the episode deck already exists, use:

**Add deck to Anki with Yomitan**

### 2. Review the Vocabulary

The extension shows the vocabulary before adding anything to Anki.

Common low-value words, particles, and fillers are hidden automatically.

You can:

* Include or remove individual words
* Ignore common beginner vocabulary
* Filter very uncommon words by frequency

These filters are optional.

### 3. Choose Your Anki Settings

Select:

* The **Anki deck** where you want the cards
* The **Yomitan card format** you want to use

The extension uses that Yomitan format to create the cards.

### 4. Add the Cards

Click:

**Add to Anki**

Yomitan creates the card information and the extension sends the finished cards to Anki.

Duplicates are skipped automatically.

When it finishes, you will see how many cards were:

* Added
* Skipped
* Unable to be added

## Other Export Options

Most users should use **Add to Anki**.

There are also two optional alternatives:

**Export TSV**
Creates a text file that can be imported into Anki manually.

**Copy for Yomitan**
Copies the vocabulary so you can use Yomitan's own note-generation tools.

## How Long Does It Take?

Small vocabulary lists are usually fairly quick.

Large episode decks can take longer because Yomitan has to create each card individually.

Cards with audio or other media also take longer than simple text cards.

You can cancel an import if necessary. Cards already added to Anki will remain there.

## Troubleshooting

### Yomitan Is Not Detected

Make sure:

* Yomitan is installed
* **Enable Yomitan API** is turned on
* You ran the Mac helper installer

If it still does not connect, completely quit Chrome, reopen it, and try again.

### Anki Is Not Detected

Make sure:

* Anki Desktop is open
* AnkiConnect is installed and enabled

### The Cards Do Not Look Right

The extension uses your **Yomitan card format and dictionaries**.

Open Yomitan and check the card format and dictionaries you selected.

### The Episode Is Not Detected

Make sure you are signed into the website and that your account is connected on the extension's setup page.

## Updating the Extension

When you receive a new version:

1. Replace the old extension folder with the new one.
2. Open `chrome://extensions`.
3. Press the **Reload** button for the extension.

Your normal setup should remain the same.
