#!/usr/bin/env bash
# The README's pictures, rendered again in one command: the real popup,
# window, and pill (readme.qml) on the demo watchlist (test/tophat/demo.json),
# its quotes the newest saved capture of it (test/capture-demo.sh), the clock
# a minute after that capture, in Tokyo Night at twice the scale. Writes
# media/*.png, or into STONKS_README_OUT (test/all.sh renders into a scratch
# folder, so the script can't quietly break). The popup's card window is
# CardWindow.qml, as in keys.sh. HOME and curl are scratch.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
out="${STONKS_README_OUT:-$plugin/media}"
moment=$(cd "$STONKS_FIXTURES/overnight" && ls -d demo-*/ | sort | tail -n 1)
moment=${moment%/}
[ -n "$moment" ] || { echo "FAIL no saved capture of the demo watchlist (test/capture-demo.sh)"; exit 1; }
stamp=${moment#demo-}
at=$(( $(date -d "${stamp:0:10} ${stamp:11:2}:${stamp:13:2}" +%s) + 60 ))
echo "the demo watchlist at $moment"

plugin_tree readme.qml
cp "$here/CardWindow.qml" "$root/plugin/"
patch_copy plugin/Panel.qml 's/^  KeyboardPanel {$/  CardWindow {/'
patch_copy plugin/Panel.qml '/readonly property int panelWidth:/a\  readonly property alias testBody: body\n  readonly property alias testCard: panel'
# Offscreen, a grab's empty pixels are black, not the window's colour, so
# the window's grab takes a ground of that colour under the body.
patch_copy plugin/App.qml '/readonly property bool ready:/a\  readonly property alias testBody: body\n  readonly property alias testKeyCatcher: keyCatcher'
patch_copy plugin/App.qml '/^      StonksBody {$/i\      Rectangle { anchors.fill: parent; color: window.color }'
patch_copy plugin/Service.qml '/readonly property var entries: feed.entries/a\  readonly property alias testFeed: feed'
patch_copy plugin/Service.qml "s/property int now: Math.floor(Date.now() \/ 1000)/property int now: $at/"
patch_copy plugin/Service.qml 's/onTriggered: root.now = Math.floor(Date.now() \/ 1000)/onTriggered: {}/'
# The pills on their strips open no popup of their own.
patch_copy plugin/BarWidget.qml '/id: panelLoader/,/source:/s/active: true/active: false/'
jq '. + { hinted: true }' "$plugin/test/tophat/demo.json" > "$HOME/.config/omarchy/grvc.stonks.json"
echo "$moment" > "$STONKS_FAKE_STATE/overnight.set"
mkdir -p "$HOME/.local/state/omarchy/current"
ln -sfn /usr/share/omarchy/themes/tokyo-night "$HOME/.local/state/omarchy/current/theme"
export STONKS_README_RAW="$work/raw"
mkdir -p "$STONKS_README_RAW" "$out"
export QT_QPA_PLATFORM=offscreen QT_SCALE_FACTOR=2
run_qs 90

# Each picture as a palette PNG, so a clone stays small: the top picture the
# pill's strip over the popup, and the pill's forms with the black between
# their strips clear.
if [ "$code" -eq 0 ]; then
  raw=$STONKS_README_RAW
  small() { local dest=$out/$1.png; shift; magick "$@" -strip -dither None -colors 128 "PNG8:$dest"; }
  small hero "$raw/strip.png" -size 1x16 xc:none "$raw/popup.png" -background none -gravity center -append
  small pill "$raw/forms.png" -transparent black
  for name in scrub lists retro window; do small "$name" "$raw/$name.png"; done
  for name in hero pill scrub lists retro window; do
    file="$out/$name.png"
    if [ -s "$file" ]; then
      echo "PASS $name.png $(magick identify -format '%wx%h' "$file"), $(( $(stat -c %s "$file") / 1024 )) KB"
    else
      echo "FAIL $name.png was not written" >> "$work/log"
      code=1
    fi
  done
fi
finish "README DONE"
