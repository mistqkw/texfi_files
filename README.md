<div align="center">

![TexFi files](assets/promo.png)

# TexFi files

**Your own "Saved Messages", by TexFi — local and without limits.**
Send text and files between your phone and computer, keep everything in your
account, and reach it from any network. No third‑party cloud, no size limits on local transfers.

![Platform](https://img.shields.io/badge/platforms-Android%20%7C%20Linux%20%7C%20Windows-4C7CFF)
![Release](https://img.shields.io/github/v/release/mistqkw/texfi_files?label=release)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-open%20source-green)

</div>

---

## ⬇️ Download

| Platform | File | Link |
|----------|------|------|
| **Android** | `app-release.apk` | [Download APK](https://github.com/mistqkw/texfi_files/releases/latest/download/app-release.apk) |
| **Windows** | `TexFi-files-windows-x64.zip` | [Download for Windows](https://github.com/mistqkw/texfi_files/releases/latest/download/TexFi-files-windows-x64.zip) |
| **Linux** | build from source | [See below](#-build-from-source) |

All releases: [github.com/mistqkw/texfi_files/releases](https://github.com/mistqkw/texfi_files/releases)

---

## ✨ Features

- ☁️ **Account cloud (hybrid)** — sign in with GitHub and your text, photos and files
  (up to ~90 MB) live in your account, reachable from **any device and any network**.
- 📁 **Any‑size local transfer** — bigger files go directly between devices on the same network.
- 🎤 **Voice messages** — record and send voice (m4a), kept separate from music.
- ↪️ **Share / forward** — send any message or file to Telegram or anywhere via the system share sheet.
- 🎵 **Built‑in player + Music library** — audio with album art, mini‑player, playlist of all chat audio; video with thumbnails.
- 🖼 **Media** — swipeable, zoomable image gallery.
- ⌨️ **Type from phone to PC** — the phone keyboard types on your computer.
- 📌 **Pin & group** — pin items, organize into collections, filter the timeline.
- 🎨 **Deep customization** — design skins (TexFi / Material / Apple / Samsung / Windows),
  any accent color, fonts, custom photo chat background (blur / pixelate / dim),
  snow & rain effects, per‑message colors, changeable animations, OLED theme.
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

Ready‑to‑use APK and Windows builds are produced by **GitHub Actions** on every version
tag (`git tag v1.2.3 && git push origin v1.2.3`) and attached to the release.

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
