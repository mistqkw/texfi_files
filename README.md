<div align="center">

![TexFi files](assets/promo.png)

# TexFi files

**Своё «Избранное», как в Telegram — только локальное и без лимитов.**
Пересылка текста и файлов любого размера между телефоном и компьютером
напрямую по Wi-Fi. Без облака, без регистрации, без ограничений на размер.

![Platform](https://img.shields.io/badge/платформы-Android%20%7C%20Linux%20%7C%20Windows-4f7cff)
![Release](https://img.shields.io/github/v/release/mistqkw/texfi_files?label=релиз)
![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter)
![License](https://img.shields.io/badge/лицензия-open%20source-green)

</div>

---

## ⬇️ Скачать

| Платформа | Файл | Ссылка |
|-----------|------|--------|
| **Android** | `app-release.apk` | [Скачать APK](https://github.com/mistqkw/texfi_files/releases/download/v1.0.0/app-release.apk) |
| **Windows** | `TexFi-files-windows-x64.zip` | [Скачать для Windows](https://github.com/mistqkw/texfi_files/releases/download/v1.0.0/TexFi-files-windows-x64.zip) |
| **Linux** | сборка из исходников | [Инструкция ниже](#-сборка-из-исходников) |

Все релизы: [github.com/mistqkw/texfi_files/releases](https://github.com/mistqkw/texfi_files/releases)

---

## ✨ Возможности

- 📁 **Файлы любого размера** — потоковая передача по локальной сети, память не забивается
- ⚡ **Мгновенно и напрямую** — текст, картинки, аудио, видео летят между устройствами
- 🎵 **Встроенный плеер** — слушай музыку и смотри видео прямо в приложении
- ⌨️ **Клавиатура телефона печатает на ПК** — с поддержкой русского (через `wtype`)
- 💾 **Скачивание принятых файлов** в пару тапов
- 🔍 **Авто-поиск устройств** в одной Wi-Fi сети + подключение по IP вручную
- 🎨 **Material 3**, тёмная и OLED-тема, акцентные цвета, настройки

---

## 📱 Как пользоваться

1. Установи TexFi files на телефон и на компьютер.
2. Подключи оба устройства к одной Wi-Fi сети.
3. Обычно они находят друг друга сами — смотри вкладку **«Устройства»**.
4. Если не нашли — открой «Устройства» на ПК, посмотри строку
   `Это устройство · 192.168.x.x:ПОРТ`, и на телефоне нажми **«По IP»**.
5. Выбери адресата в панели ввода и шли текст/файлы. Либо **«Сохранить здесь»** —
   локально, без отправки.

> **Linux + брандмауэр:** если ПК не видит телефон, открой порты:
> ```bash
> sudo firewall-cmd --permanent --add-port=45888/udp
> sudo firewall-cmd --permanent --add-port=45889-45899/tcp
> sudo firewall-cmd --reload
> ```

> **Клавиатура на ПК (Linux):** нужен `wtype` — `sudo pacman -S wtype`.

---

## 🛠 Сборка из исходников

Нужен [Flutter](https://flutter.dev) 3.44+.

```bash
git clone https://github.com/mistqkw/texfi_files.git
cd texfi_files
flutter pub get

# Linux
flutter build linux --release
bash packaging/install-linux.sh   # установить как нативное приложение

# Android
flutter build apk --release

# Windows
flutter build windows --release
```

Готовые APK и Windows-сборки собираются автоматически через **GitHub Actions**
при каждом пуше и кладутся в релиз.

---

## 🧩 Технологии

- **Flutter** — один код на Android, Linux и Windows
- **dart:io** — HTTP-сервер приёма и UDP-поиск устройств (multicast + broadcast)
- **media_kit** — встроенный аудио/видео плеер
- **wtype / ydotool** — эмуляция ввода на ПК для «клавиатуры телефона»

---

<div align="center">
Сделано с ❤️ на Flutter · open source
</div>
