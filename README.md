<div align="center">

![TexFi files](assets/promo.png)

# TexFi files

**Your own "Saved Messages", by TexFi — local and without limits.**
Send text and files between your phone and computer, keep everything in your
account, and reach it from any network. No third‑party cloud, no size limits on local transfers.

![Platform](https://img.shields.io/badge/platforms-Android%20%7C%20Linux%20%7C%20Windows-4A7DFB)
![Release](https://img.shields.io/github/v/release/mistqkw/texfi_files?label=release)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-open%20source-green)

</div>

---

## ⬇️ Download

| Platform | Install |
|----------|---------|
| **Android** | [Download APK](https://github.com/mistqkw/texfi_files/releases/latest/download/app-release.apk) |
| **Windows** | [Download for Windows](https://github.com/mistqkw/texfi_files/releases/latest/download/TexFi-files-windows-x64.zip) |
| **Linux** (x86_64) | one command — see below |

```bash
curl -fsSL https://raw.githubusercontent.com/mistqkw/texfi_files/main/install.sh | sh
```

Downloads the latest release, installs under `~/.local` (no root, nothing touched
outside your home directory) and adds it to your app menu. Works on any mainstream
glibc desktop distro — Ubuntu/Debian/Mint, Fedora, Arch, openSUSE and derivatives.
Not for musl‑based distros (Alpine, postmarketOS) or non‑x86_64 machines — build
from source instead (see [below](#-build-from-source)).

All releases: [github.com/mistqkw/texfi_files/releases](https://github.com/mistqkw/texfi_files/releases)

---

## ✨ Features

- ☁️ **Account cloud (hybrid)** — sign in with GitHub and your text, photos and files
  (up to ~90 MB) live in your account, reachable from **any device and any network**.
- 📁 **Any‑size local transfer** — bigger files go directly between devices on the same network.
- ☑️ **Multi‑select** — pick several messages or files at once (tap, or long‑press and
  drag across rows) and delete, move to a folder, or label them in one action.
- 🏷 **Labels & folders** — file anything into a folder (it stops cluttering "All" once
  it's filed) and tag it with as many labels as you like on top — labels are filterable
  from the top bar.
- 🎤 **Voice messages** — record and send voice (m4a), kept separate from music.
- ↪️ **Share / forward** — send any message or file to Telegram or anywhere via the system share sheet.
- 🎵 **Built‑in player + Music library** — pixel‑art transport controls, block seek bar,
  album art, mini‑player, playlist of all saved audio; video with thumbnails.
- 🖼 **Media** — swipeable, zoomable image gallery; GIFs are marked as such.
- ⌨️ **Type from phone to PC** — the phone keyboard types on your computer.
- 🔎 **Full‑text search** — find any saved message or file name instantly.
- 📌 **Pin & archive** — pin items and move noise to the archive, filter the timeline.
- 🎨 **Pixel‑art design** — the same visual language as the rest of the TexFi
  ecosystem (f0kus, m0ney): blocky cards with a solid offset shadow, custom
  checkboxes/switches/radios, a P2P‑node app icon, and short, tactile animations —
  no Material parts left in the interface.
- 📳 **Haptics** — a short tactile tick on taps and sends, matching the rest of the
  ecosystem's patterns; toggle in Settings.
- 🌨 **Custom background** — your own photo behind the feed, with adjustable blur,
  dim and an optional pixel snowfall.
- 🌍 **4 languages** — English, Русский, Deutsch, Polski (switch on the fly).
- 📥 **Background receive** (Android) & 🖱 **smooth scrolling** (desktop).
- 👋 **Onboarding** — an animated intro explains the app on first launch.

---

## 📱 How it works

**Account cloud (anywhere):** sign in with GitHub on each device (Settings → Account).
Small files and text sync through a private repository in your own account, so the
other device pulls them automatically — even from a different network.

**Local (same network):** large files transfer directly device‑to‑device. Devices of the
same account find each other automatically; you can also connect by IP.

> **Sign‑in:** on Android/Linux/Windows it's a simple code flow — the app shows a code,
> you paste it on `github.com/login/device`, done. Grant the **repo** permission to enable the account cloud.

> **Linux + firewall:** if the PC can't receive, open ports:
> `sudo firewall-cmd --permanent --add-port=45888/udp && sudo firewall-cmd --permanent --add-port=45889-45899/tcp && sudo firewall-cmd --reload`

---

## 🛠 Build from source

Requires [Flutter](https://flutter.dev) 3.44+.

```bash
git clone https://github.com/mistqkw/texfi_files.git
cd texfi_files
flutter pub get

flutter build linux   --release   # Linux  (then packaging/install-linux.sh)
flutter build apk     --release   # Android
flutter build windows --release   # Windows
```

`packaging/install-linux.sh` installs a locally built Linux bundle the same way
`install.sh` installs a downloaded release — same layout, same `~/.local` paths, no root.

Ready‑to‑use APK, Windows and Linux builds are produced by **GitHub Actions** on every
version tag (`git tag v1.2.3 && git push origin v1.2.3`) and attached to the release.

---

## 🧩 Tech

- **Flutter** — single codebase for Android, Linux and Windows
- **dart:io** — local HTTP transfer server; device discovery through the account
- **GitHub** — identity (OAuth device flow) + private‑repo storage for the account cloud
- **media_kit** — built‑in audio/video player

---

<div align="center">
TexFi files — a TexFi product · open source
</div>
