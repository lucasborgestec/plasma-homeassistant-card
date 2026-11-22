#!/bin/bash
# Installs (or upgrades) the widget for the current user.
set -euo pipefail
cd "$(dirname "$0")"
ID=$(python3 -c 'import json;print(json.load(open("package/metadata.json"))["KPlugin"]["Id"])')
if kpackagetool6 -t Plasma/Applet -l | grep -qx "$ID"; then
    kpackagetool6 -t Plasma/Applet -u package
else
    kpackagetool6 -t Plasma/Applet -i package
fi
echo
echo "Installed $ID. Add it with: right-click the desktop → Add or Manage Widgets → \"Home Assistant Card\"."
echo "If you upgraded, restart Plasma to load the new version: systemctl --user restart plasma-plasmashell"
