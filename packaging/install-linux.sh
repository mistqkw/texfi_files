#!/usr/bin/env bash
# Устанавливает TexFi files как нативное приложение в ~/.local (без root).
set -e

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="$PROJ/build/linux/x64/release/bundle"
OPT="$HOME/.local/opt/texfi_files"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
HICOLOR="$HOME/.local/share/icons/hicolor"

if [ ! -d "$BUNDLE" ]; then
  echo "Сначала собери: flutter build linux --release" >&2
  exit 1
fi

echo "→ Копирую бандл в $OPT"
rm -rf "$OPT"
mkdir -p "$OPT" "$BIN" "$APPS"
cp -r "$BUNDLE/." "$OPT/"

echo "→ Иконки"
# Ставим весь набор размеров, а не одну 512-ю: иконка пиксельная, и когда
# тема масштабирует 512px до 24px в панели задач, сглаживание съедает скосы
# стрелок. Готовый мелкий размер выглядит так, как нарисован.
for size in 16 24 32 48 64 128 256 512; do
  dir="$HICOLOR/${size}x${size}/apps"
  mkdir -p "$dir"
  cp "$PROJ/assets/linux/texfi-files-$size.png" "$dir/texfi-files.png"
done

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
gtk-update-icon-cache "$HICOLOR" 2>/dev/null || true

echo "✓ Установлено. Ищи «TexFi files» в меню приложений или запусти: texfi-files"
