TexFi files — your own local "Saved Messages" for Android, Linux and Windows.

## What's new in 1.1.1

Follow-up polish on top of the terminal redesign:

- 🎯 Input bar icons (attach/mic) no longer sit visibly lower than the placeholder text.
- 📏 The floating app-bar capsule no longer overflows its own border — its subtitle row
  now fits cleanly instead of poking out past the frame.
- 🖼 The mini-player is now a small draggable square showing the track's real album art
  instead of a full-width bar — drag it anywhere on screen, tap to open the full player.
- 📷 QR scanner shows a clear error and a retry button instead of a dead-end
  "unexpected error" screen.
- 🌌 First launch now ships with a dark starfield wallpaper instead of a plain gradient.
- 🔔 Android: playing music now shows proper media controls in the notification shade
  and on the lock screen (play/pause/skip), via a background media session.
- 🗑 Swipe-to-delete requires a fuller, deliberate swipe and no longer deletes instantly —
  it hides the message with a 4s Undo snackbar first.
- ⌨️ Settings no longer inherit a stray open keyboard from the chat input field.
- 🖥 Linux: removed the native GTK title bar — the app already has its own header, so the
  duplicate system strip is gone; the window is now fully borderless.

## What's new in 1.1.0

**A completely new look — terminal design.**
Messages are no longer bubbles: every item is a pure‑black block with a thin outline and
a label inset directly into the top frame line — `❯ device · type`. Timestamps and status
icons moved out from under the text into a monospace line below the block, and date
separators are now full‑width rules instead of pills.

- 🖥 **Terminal blocks** — OLED‑black fill, white 1px outline, 4px corners, inset label.
- 🎚 **Tunable** — outline brightness slider, ready‑made themes (Midnight / Catppuccin /
  Gruvbox / Matrix), and you choose what the label shows: device, type, size, time.
  Prefer the old style? One switch in Settings → Appearance brings the bubbles back.
- 🎵 **Real album art** — audio blocks show the actual cover from the track's tags.
- 🔎 **Full‑text search** — search across saved messages and file names.
- 🗄 **Archive** — move noise out of the main timeline without deleting it.
- ✨ **Refined chrome** — floating capsule app bar with the wallpaper visible behind it,
  a single rounded input pill, and copy/forward buttons that appear on hover instead of
  cluttering every message.
- ⚙️ **Settings restyled** — categories are the same framed blocks, so the whole app now
  speaks one visual language.

## Install

**Android** — download `app-release.apk`, open it on your phone and allow installation
from unknown sources.

**Windows** — download and unzip `TexFi-files-windows-x64.zip`, then run `texfi_files.exe`.

**Linux** — build from source (`flutter build linux --release`), then run
`packaging/install-linux.sh` to install it into `~/.local`.
