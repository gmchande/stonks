#!/usr/bin/env bash
# Pointer-held sorting, featured sprite direction, native wheel scrolling,
# the one cursor, its fill and the list menu's edge judged on rendered
# frames, and a resting pointer's market moment on a row, in one offscreen
# window. No surface is added to the running shell.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plugin_tree pointer.qml
frame_tools
export QT_QPA_PLATFORM=offscreen
export STONKS_WATCHLIST_FIXTURE="$STONKS_FIXTURES/watchlist-22.json"
export STONKS_CALENDARS="$plugin/calendars.json"
run_qs 90
finish "POINTER DONE"
