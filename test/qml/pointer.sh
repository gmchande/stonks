#!/usr/bin/env bash
# Pointer-held sorting, featured sprite direction, and native wheel scrolling
# in one offscreen window. No surface is added to the running shell.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plugin_tree pointer.qml
export QT_QPA_PLATFORM=offscreen
export STONKS_WATCHLIST_FIXTURE="$STONKS_FIXTURES/watchlist-22.json"
run_qs 30
finish "POINTER DONE"
