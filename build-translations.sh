#!/bin/bash
# Extracts translatable strings to po/template.pot, merges them into each po/*.po
# and compiles the .mo files into the package.
set -euo pipefail
cd "$(dirname "$0")"
ID=$(python3 -c 'import json;print(json.load(open("package/metadata.json"))["KPlugin"]["Id"])')
DOMAIN="plasma_applet_${ID}"

find package -name '*.qml' -o -name '*.js' | sort | xargs xgettext \
    --from-code=UTF-8 --language=JavaScript -C \
    -ki18n -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    --package-name="$ID" --msgid-bugs-address="$(python3 -c 'import json;print(json.load(open("package/metadata.json"))["KPlugin"].get("BugReportUrl",""))')" \
    -o po/template.pot

for po in po/*.po; do
    lang=$(basename "$po" .po)
    msgmerge --quiet --update --backup=none "$po" po/template.pot
    mkdir -p "package/contents/locale/$lang/LC_MESSAGES"
    msgfmt -o "package/contents/locale/$lang/LC_MESSAGES/${DOMAIN}.mo" "$po"
    echo "compiled $lang"
done
