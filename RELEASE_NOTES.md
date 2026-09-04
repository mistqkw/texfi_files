TexFi files — your own local "Saved Messages" for Android, Linux and Windows.

## What's new in 1.5.0

- 🔷 **Smaller app icon.** The mark filled three quarters of the canvas and the
  launcher's circular mask cropped it almost to the edge. The adaptive layer is now
  a separate image at 52% — comfortably inside the safe zone.
- ⌨️ **The keyboard stops dragging the screen with it.** Only the composer lifts now;
  the background, the snow and the feed stay put. It also no longer reappears by
  itself after returning from another screen, and tapping the feed dismisses it.
- ☑️ **Selection.** Pick items and delete them, move them to a folder, or label them
  in one action. Long-press and drag paints the selection across rows.
- 🏷 **Labels.** Mark any message or file with as many labels as you like — separate
  from folders, shown on the card, and filterable from the top bar.
- 📁 **Folders actually unload the feed.** An item filed into a folder now lives
  there and no longer also shows up under "All".
- 🎵 **The music player is pixel art now** — square transport buttons, a block seek
  bar you can tap or drag, and no Material parts left.

## What's new in 1.4.0

Full UI rebuild on the design-token architecture the rest of the TexFi ecosystem
uses, so files, f0kus and m0ney genuinely share a vocabulary rather than merely
resembling each other.

- 🎨 **New visual language.** Cards and buttons carry a 2px pixel border and a solid
  offset shadow with no blur; pressing one sinks it into its own shadow like a
  physical key, without shifting the layout. Checkboxes, switches and radios are
  custom pixel versions — no Material controls left in the interface. Press Start 2P
  is used only for titles, section headers, button labels and large accent numbers;
  everything you actually read is set in a bundled grotesque.
- 🔷 **New app icon** — a P2P node, checked at 60px and 32px before generating every
  platform format. The whole icon set was redrawn on a single 10×10 grid with a
  consistent two-cell stroke.
- 📶 **Transfers are events now.** A completed file transfer gives a burst of pixel
  particles with a checkmark, a haptic receipt, and a few blinks of the cursor in
  the logo. Progress is a pixel block bar in both directions instead of a Material
  spinner. A device appearing on the network announces itself by name.
- 📄 **Files you send are recognised** — archives, documents and source files get
  their own icon instead of a generic sheet, and animated GIFs are marked as such.
- 📳 **Haptics**, with patterns matching the ecosystem, and an on/off setting.
- 🌨 **Background:** custom photo, snow with three speeds, adjustable blur and dim.
- 🐛 **Header overlap fixed.** The app name and status line used to sit in an AppBar
  with a hard-coded height while both scaled with the UI scale setting, so past
  roughly 115% they printed on top of each other. The capsule height is now derived
  from the text actually drawn in it.
- ⚡ **Faster.** Every image and video row used to hit the filesystem synchronously
  on each rebuild — and the feed rebuilds on every scroll frame. Photos were decoded
  at full camera resolution behind a 280px preview. The feed list was rebuilt several
  times per frame, and device discovery rebuilt the entire screen every 12 seconds
  even when nothing had changed. All four are fixed.
- ⚙️ **Settings cut roughly in half**, keeping what changes behaviour and dropping
  the cosmetics. Obsolete stored values are cleaned up on upgrade.

## What's new in 1.1.9

- 📁 **Archive/group are now reliably reachable.** Both were only accessible via a
  long-press on a message — but every message is also wrapped in a swipeable row
  (swipe-to-delete/forward), and that swipe gesture and the long-press gesture compete
  for the same touch, so the long-press could silently lose and the menu never opened.
  Added a small always-tappable "⋯" icon next to each message's timestamp/status row
  that opens the same menu with a plain tap — no gesture race involved.
- ☁️ **Archive/group/pin now actually sync to the cloud.** They were being saved
  locally but never sent to the shared account index after the first upload, so
  archiving or grouping a message that was already synced silently didn't show up on
  your other devices. Now every change is pushed, and incoming changes from other
  devices are picked up on the next sync.
- 🔒 **Biometric unlock, round two.** Closed a gap in the 1.1.8 fix: the guard against
  overlapping fingerprint prompts was per-screen-instance, so it wouldn't have helped
  if the lock screen ever got recreated mid-attempt. Also: if biometrics genuinely
  aren't available (not enrolled, hardware busy, etc.), the app now says so instead of
  the fingerprint button silently doing nothing.
- 🐛 Fixed a crash risk in voice recording (start/stop could call setState after the
  screen was already gone) and a couple of other minor async-safety gaps found in a
  full sweep.
- ⚡ Filter bar (All/Pinned/Archive/groups) now computes from a single pass over the
  list instead of four separate passes on every redraw.
- ✨ Small animation pass: the filter bar animates in/out instead of popping, and
  switching between All/Pinned/Archive/a group now cross-fades instead of jump-cutting.

## What's new in 1.1.8

- 🔒 **Fixed: fingerprint unlock stopped responding after the first try.** Found live on
  device: the automatic biometric prompt on the lock screen could end up starting twice in
  close succession, and Android's BiometricPrompt doesn't handle two overlapping requests —
  once that happens, it wedges completely, so even a manual tap on the fingerprint icon does
  nothing at all (confirmed via an empty device log right after the tap). Added a guard so
  only one biometric attempt can be in flight at a time; further taps while one is already
  running are ignored instead of triggering a second, conflicting request.

## What's new in 1.1.7

The 1.1.6 media-shade fix worked in local debug testing but not in the actual GitHub
release — because a *release* build is different in one specific way: Flutter enables
Android resource shrinking by default for release APKs. Our new notification icons are
only referenced by string at runtime (`getResources().getIdentifier(...)`), which the
shrinker can't see as "used", so it silently deleted them from the release build only —
verified by pulling the real GitHub-release APK from a device and checking its resources
directly, they weren't in there. Added an explicit keep-rule
(`android/app/src/main/res/raw/keep.xml`) instead of disabling shrinking altogether;
confirmed this time by building a real `--release` APK locally and checking its resources
before publishing — the icons are in there now.

## What's new in 1.1.6

Both remaining Android issues are fixed and confirmed working on a real device this time.

- 🔔 **Music now shows up in the notification shade with album art** — found via live
  device logs: `audio_service`'s bundled notification-button icons don't reliably resolve
  on modern Android, which threw an exception on the very first `setPlaybackState` call
  and silently prevented the whole media session (and notification) from ever being
  created. Added our own icon resources for play/pause/stop/skip and wired them in —
  verified live: the shade now shows the real media player with cover art and controls.
- 📷 **QR scanner actually opens the camera now.** Not a permission issue after all —
  confirmed via device log that camera access was already granted while the scanner
  still failed to start. Root cause is unclear on mobile_scanner's side, but reverting to
  its default camera-start sequence (instead of a manual delayed start) fixed it —
  verified live with the camera preview and scan frame rendering correctly.
- 🐛 **Fixed an upload retry loop.** The automatic re-push added in 1.1.4 could get stuck
  retrying a file upload forever if a previous attempt partially succeeded (file uploaded
  but the index update failed) — GitHub correctly rejected the repeat upload, but nothing
  stopped the retry. Uploads now check whether the file is already there before retrying.

## What's new in 1.1.5

- 🔒 **App re-locks every time you reopen it.** If PIN/fingerprint lock is on, the app now
  re-locks whenever it goes to the background — before, unlocking once left it open for
  anyone while it sat in the background. The biometric prompt itself no longer counts as
  "backgrounding", so it won't double-ask.
- 📷 **QR scanner: camera permission is now requested up-front** (via permission_handler)
  before the scanner opens, which fixes the "Could not start the camera" dead-end — the
  scanner's own permission request used to race the camera start and fail. If it was
  permanently denied, the message now offers a shortcut to app settings.
- 🔔 **Media-shade notification, another go:** notification permission is requested through
  permission_handler (more reliable than the plugin's own request), and the notification
  now uses a proper monochrome status icon — a colored launcher icon as the small icon
  silently breaks the notification on some Android builds.

If music still doesn't appear in the shade after this, it's most likely that notification
permission is turned off for the app in Android settings — enable it there.

## What's new in 1.1.4

Bug-fix and polish pass across the whole app.

- 🐛 **Cloud now saves bursts of messages.** Sending many messages quickly could
  drop some from the cloud: every message hit the shared index at once and the
  optimistic-concurrency writes fought each other (409s) until some gave up. Index
  writes are now strictly serialized, retried more, and any item that still failed to
  upload is automatically re-pushed on the next sync — so nothing silently stays local.
- 👆 **Fingerprint unlock works on Android.** The activity now extends a FragmentActivity
  (required by the biometric prompt); before, it silently failed.
- 🎨 **Album art in the notification shade.** The media notification now carries the real
  cover (written out and passed as artUri), and stays visible when paused.
- 🪟 **Context menu is now a small popup next to the message** with a scale/fade animation,
  anchored at your finger / cursor — instead of the big bottom sheet. Right-click works too.
- 📏 **Top bar is genuinely compact now** — logo and status collapsed into a single short
  row, the separate subtitle strip is gone.
- 🖼 **Photo viewer upgraded** — swipe down to dismiss (background fades as you drag),
  double-tap to zoom to a point, tap to hide/show the chrome, plus share/open actions.
- ⚡ **Less lag** — album-art and track-tag reading moved off the UI thread into a
  background isolate (with caching), so scrolling the music list and starting tracks no
  longer janks.
- 📷 QR scanner: torch toggle, a centered scan frame, and a guard against double-handling.

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
