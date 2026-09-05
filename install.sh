#!/bin/sh
# TexFi files — one-command installer for Linux desktops.
#
#   curl -fsSL https://raw.githubusercontent.com/mistqkw/texfi_files/main/install.sh | sh
#
# Downloads the latest prebuilt release, installs it under ~/.local (no
# root, nothing touched outside your home directory) and registers it with
# your desktop menu. Works on any mainstream glibc distro with a graphical
# desktop — Ubuntu/Debian/Mint, Fedora/RHEL, Arch, openSUSE and their
# derivatives. It will NOT work on musl-based distros (Alpine,
# postmarketOS): Flutter's Linux engine is built against glibc. For those,
# or for architectures other than x86_64, build from source instead — see
# the "Build from source" section in the README.
#
# POSIX sh only (no bashisms): this has to run correctly under whatever
# /bin/sh happens to be on the machine — dash on Debian/Ubuntu, busybox ash
# elsewhere — not just bash.
set -e

REPO="mistqkw/texfi_files"
ASSET="TexFi-files-linux-x64.tar.gz"
OPT="$HOME/.local/opt/texfi_files"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"
HICOLOR="$HOME/.local/share/icons/hicolor"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}
need curl
need tar

machine="$(uname -m)"
case "$machine" in
  x86_64 | amd64) ;;
  *)
    echo "No prebuilt build for '$machine' — only x86_64 is published." >&2
    echo "Build from source instead: see README.md → Build from source." >&2
    exit 1
    ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

url="https://github.com/$REPO/releases/latest/download/$ASSET"
echo "-> Downloading $url"
curl -fsSL "$url" -o "$tmp/texfi.tar.gz"

echo "-> Extracting"
tar -xzf "$tmp/texfi.tar.gz" -C "$tmp"

if [ ! -x "$tmp/bundle/texfi_files" ]; then
  echo "Release archive did not contain the expected binary (bundle/texfi_files)." >&2
  exit 1
fi

echo "-> Installing to $OPT"
rm -rf "$OPT"
mkdir -p "$OPT" "$BIN_DIR" "$APPS_DIR"
cp -r "$tmp/bundle/." "$OPT/"

echo "-> Icons"
if [ -d "$tmp/icons" ]; then
  for f in "$tmp"/icons/*.png; do
    [ -f "$f" ] || continue
    size="$(basename "$f" .png)"
    dir="$HICOLOR/${size}x${size}/apps"
    mkdir -p "$dir"
    cp "$f" "$dir/texfi-files.png"
  done
fi

ln -sf "$OPT/texfi_files" "$BIN_DIR/texfi-files"

cat > "$APPS_DIR/texfi-files.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=TexFi files
Comment=Your own local "Saved Messages": files and text between your devices
Exec=$OPT/texfi_files
Icon=texfi-files
Terminal=false
Categories=Network;FileTransfer;Utility;
StartupWMClass=texfi_files
EOF

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache "$HICOLOR" >/dev/null 2>&1 || true

echo
echo "Done. TexFi files is installed."
case ":$PATH:" in
  *":$BIN_DIR:"*) echo "Run it: texfi-files" ;;
  *) echo "Add $BIN_DIR to your PATH, or launch \"TexFi files\" from your app menu." ;;
esac

# The built-in player links against libmpv, which is a system library on
# Linux rather than something bundled into the release archive. Most
# desktop distros already have it (it's a dependency of mpv/VLC-adjacent
# tooling), but not all — check and say so plainly instead of letting the
# player fail silently later.
if command -v ldconfig >/dev/null 2>&1 && ! ldconfig -p 2>/dev/null | grep -q "libmpv\.so"; then
  echo
  echo "Note: libmpv was not found — the built-in audio/video player needs it."
  echo "Everything else (transfers, text, files) works without it. Install with:"
  echo "  Debian/Ubuntu:  sudo apt install libmpv2"
  echo "  Fedora:         sudo dnf install mpv-libs"
  echo "  Arch:           sudo pacman -S mpv"
  echo "  openSUSE:       sudo zypper install libmpv2"
fi
