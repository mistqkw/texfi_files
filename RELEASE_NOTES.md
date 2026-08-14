TexFi files — your own local "Saved Messages" for Android, Linux and Windows.

## What's new in 1.1.3

**Music tab redesign** — tracks now show their real album art (or a framed icon in
terminal mode), and the header gained shuffle/repeat toggles (the full-screen player
has them too).

- 🎵 Music tab: real album art per track, terminal-style framed rows with track number
  in the inset label, shuffle and repeat (off/all/one) both in the list and full player.
- 🔍 Search field restyled to match the terminal look (black pill, white border) — it
  was rendering with the plain default style before and was easy to miss.
- 📱 Android: switched to true edge-to-edge display with a transparent status bar. The
  opaque system status bar was sitting on top of the app-bar capsule and the two
  visually merged into one oversized bar — that combination doesn't exist on desktop,
  which is why it looked fine there but not on phones.
- ⌨️ Settings screen now force-clears focus on entry regardless of how it was reached,
  as an extra guard against the keyboard leaking in from wherever it was last open.
- 🔔 Android media notification: the permission request now also retries once the app's
  UI is fully up, in case the very early request (before the first frame) didn't have a
  ready Activity to prompt through on some devices.
- ✨ New boot animation: a terminal boot sequence (logo, then `❯ texfi files_` typed out
  with a blinking cursor) instead of the old plain fade-in.
- 👋 Welcome/onboarding screens restyled to match the terminal look when it's enabled.

## What's new in 1.1.2

**Important data-loss fix.** A bug in cloud sync could treat a single failed or
incomplete GitHub API response as "this message was deleted on another device" and
wipe it out locally — sometimes permanently, with no way to bring it back. Deletions
now require the message to be confirmed missing across several sync cycles in a row
before anything is removed, and an empty/broken index response no longer triggers any
deletions at all.

- 🐛 **Fixed: messages disappearing on their own.** See above — this was the big one.
- 🖱 Right-click on a message now opens the same menu as long-press (desktop).
- 📏 App-bar capsule shrunk further — it was still noticeably taller than it needed to be.
- 🔔 Android: explicitly requests notification permission before starting the media
  session, so the shade/lock-screen controls aren't silently blocked by the OS on
  Android 13+ when background-receive is off.

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
