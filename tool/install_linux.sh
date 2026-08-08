#!/usr/bin/env bash
# Installs FileFly for the current user: no root, no system directories.
# Re-run it after a rebuild to update the installed copy.
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
BUNDLE="$REPO/build/linux/x64/release/bundle"
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$PREFIX/filefly"
BIN_DIR="$HOME/.local/bin"
DESKTOP_FILE="$PREFIX/applications/filefly.desktop"

if [[ ! -x "$BUNDLE/filefly" ]]; then
  echo "No hay build release. Corre primero:" >&2
  echo "  flutter build linux --release" >&2
  exit 1
fi

echo "==> Copiando la app a $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -r "$BUNDLE/." "$APP_DIR/"

echo "==> Instalando iconos"
for size in 16 22 24 32 48 64 128 256 512; do
  icon_dir="$PREFIX/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$icon_dir"
  cp "$REPO/assets/icons/filefly-${size}.png" "$icon_dir/filefly.png"
done

echo "==> Creando el lanzador"
mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=FileFly
GenericName=Transferencia de archivos
Comment=Transfiere archivos entre la PC y el celular por la red local
Exec=$APP_DIR/filefly
Icon=filefly
Terminal=false
Categories=Network;FileTransfer;
Keywords=archivos;transferencia;qr;celular;red;wifi;
StartupNotify=true
StartupWMClass=dev.jose.FileFly
DESKTOP
chmod +x "$DESKTOP_FILE"

echo "==> Enlace en $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sf "$APP_DIR/filefly" "$BIN_DIR/filefly"

# Menus and icon themes are cached; without this the entry can take a
# relogin to appear.
command -v update-desktop-database >/dev/null && \
  update-desktop-database "$PREFIX/applications" || true
command -v gtk-update-icon-cache >/dev/null && \
  gtk-update-icon-cache -f -t "$PREFIX/icons/hicolor" >/dev/null 2>&1 || true

echo
echo "FileFly instalado."
echo "  Menu:      buscalo como \"FileFly\""
echo "  Terminal:  filefly   (si ~/.local/bin esta en el PATH)"
echo "  Desinstalar: tool/uninstall_linux.sh"
