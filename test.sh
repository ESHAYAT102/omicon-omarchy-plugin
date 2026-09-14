#!/bin/bash
set -euo pipefail

test -x ./choose-image
python3 -c 'compile(open("choose-image", encoding="utf-8").read(), "choose-image", "exec")'
python3 -c 'import gi; gi.require_version("Gtk", "3.0"); from gi.repository import Gtk'
! grep -q 'QtQuick.Dialogs\|FileDialog' Panel.qml
grep -q '"barWidget": "BarWidget.qml"' manifest.json
omarchy plugin validate .

test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/home" "$test_dir/system/applications"
cp /usr/share/omarchy/icon.png "$test_dir/icon.png"
cp /usr/share/omarchy/icon.png "$test_dir/home/icon.png"
printf '[Desktop Entry]\nName=Test App\nType=Application\nExec=true\nIcon=old\n' >"$test_dir/system/applications/test.app.desktop"

HOME="$test_dir/home" XDG_DATA_HOME="$test_dir/share" XDG_DATA_DIRS="$test_dir/system" \
  XDG_STATE_HOME="$test_dir/state" ./apply-icon apply test.app '~/icon.png'

desktop="$test_dir/share/applications/test.app.desktop"
test -f "$desktop"
test "$(grep -c '^Icon=' "$desktop")" = 1
grep -q '^Name=Test App$' "$desktop"
desktop-file-validate "$desktop"
HOME="$test_dir/home" XDG_DATA_HOME="$test_dir/share" XDG_DATA_DIRS="$test_dir/system" \
  XDG_STATE_HOME="$test_dir/state" ./apply-icon list | grep -q '^test.app'
HOME="$test_dir/home" XDG_DATA_HOME="$test_dir/share" XDG_DATA_DIRS="$test_dir/system" \
  XDG_STATE_HOME="$test_dir/state" ./apply-icon revert test.app
test ! -e "$desktop"

cp "$test_dir/system/applications/test.app.desktop" "$desktop"
sed -i 's/^Icon=.*/Icon=user-original/' "$desktop"
HOME="$test_dir/home" XDG_DATA_HOME="$test_dir/share" XDG_DATA_DIRS="$test_dir/system" \
  XDG_STATE_HOME="$test_dir/state" ./apply-icon apply test.app "$test_dir/icon.png"
HOME="$test_dir/home" XDG_DATA_HOME="$test_dir/share" XDG_DATA_DIRS="$test_dir/system" \
  XDG_STATE_HOME="$test_dir/state" ./apply-icon revert test.app
grep -q '^Icon=user-original$' "$desktop"
