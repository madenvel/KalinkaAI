#!/usr/bin/env bash
#
# Registers Kalinka with the desktop environment so it shows up in the app
# launcher / dock with the right name and icon. Run it from the extracted
# tarball directory (the one containing the `kalinka` binary):
#
#   ./install.sh              install for the current user
#   ./install.sh --uninstall  remove a previous install
#
# It installs nothing system-wide and needs no root: files go under
# $XDG_DATA_HOME (~/.local/share by default). The app keeps running from
# wherever you extracted it — this only writes the desktop entry + icon.
set -euo pipefail

APP_ID="org.kalinka.kalinka"
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS_DIR="$DATA_HOME/applications"
ICON_DIR="$DATA_HOME/icons/hicolor/512x512/apps"

refresh() {
  update-desktop-database "$APPS_DIR" 2>/dev/null || true
  gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" 2>/dev/null || true
}

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$APPS_DIR/$APP_ID.desktop" "$ICON_DIR/$APP_ID.png"
  refresh
  echo "Kalinka desktop entry removed."
  exit 0
fi

mkdir -p "$APPS_DIR" "$ICON_DIR"

install -m644 "$BUNDLE_DIR/data/kalinka.png" "$ICON_DIR/$APP_ID.png"

sed -e "s|@EXEC@|$BUNDLE_DIR/kalinka|" \
    -e "s|@ICON@|$APP_ID|" \
    "$BUNDLE_DIR/$APP_ID.desktop" > "$APPS_DIR/$APP_ID.desktop"
chmod 644 "$APPS_DIR/$APP_ID.desktop"

refresh
echo "Kalinka installed for $USER. Look for it in your app launcher."
echo "  binary:  $BUNDLE_DIR/kalinka"
echo "  uninstall: $BUNDLE_DIR/install.sh --uninstall"
