# Container Notes for Unraid

A lightweight plugin for [Unraid](https://unraid.net) that adds a persistent, editable note row beneath each Docker container (and folder group) on the Docker page.

> Built and tested on **Unraid 7.3** with **FolderView2** (docker.folder plugin). Compatible with all Unraid themes.

---

## Features

- Per-container notes -- each container has its own independent note
- FolderView2 support -- notes appear on folder group rows as well as individual containers
- Persistent storage -- notes saved to `/boot/config/plugins/container-notes/notes.json` (survives reboots)
- Theme-aware -- uses Unraid's own CSS variables, works on all themes (white, black, grey, etc.)
- No page reload needed -- notes save instantly via background API call
- Keyboard shortcuts -- `Ctrl+Enter` to save, `Escape` to cancel

---

## What It Looks Like

Each container row gets a slim note bar directly beneath it:

- **No note yet:** a faint grey *"Add a note..."* prompt with a pencil icon
- **Note saved:** the note text is shown in full, bold dark text; pencil turns orange
- **Editing:** an inline text area appears with Save / Cancel buttons

---

## Installation

### One-line install (recommended)

Open the Unraid terminal and paste the contents of [`install.sh`](./install.sh), then press **Enter**.

Once it prints `Done!`, do a hard-refresh of your Docker page: **Ctrl+Shift+R** in your browser.

### What the installer does

1. Writes plugin files to `/usr/local/emhttp/plugins/container-notes/`
2. Backs them up to `/boot/config/plugins/container-notes/` (persistent across reboots)
3. Adds a restore hook to `/boot/config/go` so files are re-created on every boot
4. Creates an uninstaller at `/boot/config/plugins/container-notes/uninstall.sh`

---

## Uninstalling

In the Unraid terminal:

```bash
bash /boot/config/plugins/container-notes/uninstall.sh
```

Your notes data is kept at `/boot/config/plugins/container-notes/notes.json`. Delete that folder manually if you want to remove your notes too.

---

## How Notes Are Stored

Notes are stored as a simple JSON file on your USB boot drive:

```
/boot/config/plugins/container-notes/notes.json
```

Example:

```json
{
  "Nextcloud": "Main cloud storage -- port 443 via nginx proxy",
  "folder:03 - Core Service": "All critical self-hosted services. Don't auto-update without testing.",
  "AdGuard-Home": "DNS filtering -- fallback to Quad9 if this goes down"
}
```

Folder notes are keyed with a `folder:` prefix to avoid clashing with container names.

---

## Compatibility

| Unraid Version | FolderView2 | Status |
|---|---|---|
| 7.3 | Yes | Tested and working |
| 7.x | Yes | Should work |
| 7.x | No  | Should work |
| 6.x | Any | Not tested |

---

## Files

```
container-notes/
+-- install.sh                          <- Run this on your Unraid server
+-- source/
    +-- usr/local/emhttp/plugins/container-notes/
        +-- container-notes.js          <- DOM injection & UI logic
        +-- container-notes.page        <- Unraid plugin page definition
        +-- notes_api.php               <- Save/load API endpoint
```

---

## Credits

Built by [WackyRazzy](https://github.com/WackyRazzy) with assistance from Claude (Anthropic).
Inspired by the need to keep track of 40+ Docker containers without losing my mind.

---

## License

MIT -- do whatever you like with it.