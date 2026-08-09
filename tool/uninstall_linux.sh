#!/usr/bin/env bash
# Quita lo que creó install_linux.sh. No toca la carpeta compartida ni el
# token: esos son tus datos, no la app.
set -euo pipefail

PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}"

rm -rf "$PREFIX/filefly"
rm -f "$PREFIX/applications/filefly.desktop"
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/filefly.desktop"
rm -f "$HOME/.local/bin/filefly"
for size in 16 22 24 32 48 64 128 256 512; do
  rm -f "$PREFIX/icons/hicolor/${size}x${size}/apps/filefly.png"
done

command -v update-desktop-database >/dev/null && \
  update-desktop-database "$PREFIX/applications" || true
command -v gtk-update-icon-cache >/dev/null && \
  gtk-update-icon-cache -f -t "$PREFIX/icons/hicolor" >/dev/null 2>&1 || true

echo "FileFly desinstalado."
echo "Tu carpeta compartida y el token siguen en su lugar:"
echo "  ~/FileFly"
echo "  ~/.config/filefly"
