#!/usr/bin/env bash
# Устанавливает TexFi files как нативное приложение в ~/.local (без root).
set -e

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$PROJ/build/linux/x64/release/bundle"
OPT="$HOME/.local/opt/texfi_files"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/512x512/apps"

if [ ! -d "$BUNDLE" ]; then
  echo "Сначала собери: flutter build linux --release" >&2
  exit 1
fi

echo "→ Копирую бандл в $OPT"
rm -rf "$OPT"
mkdir -p "$OPT" "$BIN" "$APPS" "$ICONS"
cp -r "$BUNDLE/." "$OPT/"

echo "→ Иконка"
cp "$PROJ/assets/icon_512.png" "$ICONS/texfi-files.png"

echo "→ Ярлык запуска"
ln -sf "$OPT/texfi_files" "$BIN/texfi-files"

cat > "$APPS/texfi-files.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=TexFi files
Comment=Локальное «Избранное»: файлы и текст между устройствами
Exec=$OPT/texfi_files
Icon=texfi-files
Terminal=false
Categories=Network;FileTransfer;Utility;
StartupWMClass=texfi_files
EOF

update-desktop-database "$APPS" 2>/dev/null || true
gtk-update-icon-cache "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "✓ Установлено. Ищи «TexFi files» в меню приложений или запусти: texfi-files"
