<div align="center">

![TexFi files](assets/promo.png)

# TexFi files

**Your own "Saved Messages", by TexFi — local and without limits.**
Send text and files between your phone and computer, keep everything in your
account, and reach it from any network. No third‑party cloud, and no size
limit on local transfers.

![Platform](https://img.shields.io/badge/platforms-Android%20%7C%20Linux%20%7C%20Windows-4A7DFB)
![Release](https://img.shields.io/github/v/release/mistqkw/texfi_files?label=release)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-open%20source-green)

</div>

---

## Download

| Platform | Install |
|----------|---------|
| **Android** | [Download APK](https://github.com/mistqkw/texfi_files/releases/latest/download/app-release.apk) |
| **Windows** | [Download for Windows](https://github.com/mistqkw/texfi_files/releases/latest/download/TexFi-files-windows-x64.zip) |
| **Linux** (x86_64) | one command — see below |

```bash
curl -fsSL https://raw.githubusercontent.com/mistqkw/texfi_files/main/install.sh | sh
```

This grabs the latest release and installs it under `~/.local` (no root,
nothing touched outside your home directory), then adds it to your app menu.
Works on any mainstream glibc desktop distro — Ubuntu/Debian/Mint, Fedora,
Arch, openSUSE and derivatives. Not for musl‑based distros (Alpine,
postmarketOS) or non‑x86_64 machines; build from source instead, see
[below](#build-from-source). The built‑in player needs `libmpv`, a system
library that isn't bundled — the installer checks for it and tells you which
package to grab for your distro if it's missing. Everything else works fine
without it.

All releases: [github.com/mistqkw/texfi_files/releases](https://github.com/mistqkw/texfi_files/releases)

---

## Features

- **Account cloud (hybrid).** Sign in with GitHub and your text, photos and
  files (up to ~90 MB) live in your account, reachable from any device on any
  network.
- Bigger files skip the cloud and go straight between devices on the same
  network — no size cap.
- Multi‑select: tap, or long‑press and drag across rows, then delete, move to
  a folder, or label everything you picked in one go.
- Folders and labels. Filing something into a folder gets it out of "All";
  labels stack on top of that and filter from the top bar.
- Voice messages, recorded as m4a, kept separate from music.
- Share or forward anything to Telegram or wherever, through the normal system
  share sheet.
- A built‑in player and music library — pixel‑art transport controls, a block
  seek bar, album art, a mini‑player, and a playlist of everything you've
  saved. Video gets thumbnails.
- MPRIS on Linux, so the player shows up in GNOME Shell/KDE Plasma media
  widgets and responds to media keys and `playerctl` like any native desktop
  player. Cover art, position, shuffle and repeat stay in sync both ways.
- A gallery for images — swipeable, zoomable, and GIFs get marked as GIFs.
- Type on your phone, watch it appear on your computer.
- Full‑text search across saved messages and file names.
- Pin things, archive the noise, filter the timeline.
- Pixel‑art design throughout, the same visual language as the rest of the
  TexFi apps (f0kus, m0ney): blocky cards with an offset shadow, custom
  checkboxes/switches/radios, a P2P‑node icon, no Material left anywhere.
- Haptics on taps and sends, matching the rest of the ecosystem — toggle it
  off in Settings if you'd rather not.
- Custom background: your own photo behind the feed, adjustable blur and dim,
  plus an optional pixel snowfall.
- Four languages: English, Русский, Deutsch, Polski, switchable on the fly.
- Background receive on Android, smooth scrolling on desktop.
- A short animated onboarding walks you through it on first launch.

---

## How it works

**Account cloud (anywhere):** sign in with GitHub on each device (Settings →
Account). Small files and text sync through a private repository in your own
account, so the other device just pulls them, even from a completely
different network.

**Local (same network):** large files go directly device‑to‑device. Devices
signed into the same account find each other automatically, or you can
connect by IP.

> **Sign‑in:** on Android/Linux/Windows it's a simple code flow — the app
> shows a code, you paste it on `github.com/login/device`, done. Grant the
> **repo** permission to enable the account cloud.

> **Linux + firewall:** if the PC can't receive anything, open these ports:
> `sudo firewall-cmd --permanent --add-port=45888/udp && sudo firewall-cmd --permanent --add-port=45889-45899/tcp && sudo firewall-cmd --reload`

---

## Build from source

Requires [Flutter](https://flutter.dev) 3.44+.

```bash
git clone https://github.com/mistqkw/texfi_files.git
cd texfi_files
flutter pub get

flutter build linux   --release   # Linux  (then packaging/install-linux.sh)
flutter build apk     --release   # Android
flutter build windows --release   # Windows
```

`packaging/install-linux.sh` installs a locally built Linux bundle the same
way `install.sh` installs a downloaded release — same `~/.local` layout, no
root either way.

Ready‑to‑use APK, Windows and Linux builds come out of GitHub Actions on
every version tag (`git tag v1.2.3 && git push origin v1.2.3`) and get
attached to the release automatically.

---

## Tech

- **Flutter** — one codebase for Android, Linux and Windows
- **dart:io** — the local HTTP transfer server; device discovery goes through the account
- **GitHub** — identity via OAuth device flow, plus a private repo for the account cloud
- **media_kit** — the built‑in audio/video player

---

<div align="center">
TexFi files — a TexFi product · open source
</div>
