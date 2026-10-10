#!/usr/bin/env bash
# Every check in one command: model tests, source boundaries, QML lint, manifest and launcher validation,
# the Quickshell harnesses, and the offscreen renders. The harnesses run side
# by side, each with its own HOME, QML cache, and fake curl state (lib.sh),
# while the quick checks run; each one's output prints in order, with its
# time. Exits non-zero on any failure. Needs the Wayland session for the
# harnesses. Without the saved answers (test/fixtures-dir.sh), the checks
# that read them skip, each naming why, and the last line counts them:
# ALL PASS only when nothing skipped.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
status=0
# Before anything runs: every harness script sources lib.sh, ends on finish
# and its finish line, and is started below. A script that misses one can
# pass without its checks having run. The daily totals (fetch-day.sh) are
# a measurement, run by hand; quickshell.sh is lib.sh's runner, and
# crash-check.sh proves it without the saved answers.
for script in test/qml/*.sh; do
  name=${script##*/}
  case "$name" in lib.sh|quickshell.sh|crash-check.sh|render.sh|fetch-day.sh) continue ;; esac
  grep -q '^source .*/lib\.sh"$' "$script" || echo "FAILED $script does not source lib.sh"
  tail -n 1 "$script" | grep -qE '^finish "[^"]+"$' || echo "FAILED $script does not end with finish \"...\""
  grep -qE "^start .* bash test/qml/${name//./\\.}$" test/all.sh || echo "FAILED $script is not started by test/all.sh"
done | grep . && { echo "SOME FAILED"; exit 1; }

logs=$(mktemp -d)
labels=()
pids=()
# Each harness runs in a process group of its own, which holds everything it
# starts, so an interrupt stops exactly those groups: never a process by
# name, since the owner's shell and other runs are Quickshells too. It waits
# for them to empty, as each harness stops its own Quickshell's group, so
# nothing the suite started outlives it.
stop_all() {
  local pid i
  for pid in "${pids[@]}"; do kill -- "-$pid" 2> /dev/null; done
  for pid in "${pids[@]}"; do
    for i in $(seq 50); do pgrep -g "$pid" > /dev/null || break; sleep 0.2; done
  done
  exit 130
}
trap stop_all INT TERM
trap 'rm -rf "$logs"' EXIT

# centiseconds: time since boot, which a clock change does not move.
centiseconds() {
  local up
  read -r up _ < /proc/uptime
  echo "${up/./}"
}

# start LABEL COMMAND...: runs COMMAND in the background, in a process group
# of its own (job control, set -m), into its own log, noting its time in
# centiseconds beside it.
start() {
  local log="$logs/${#pids[@]}"
  labels+=("$1")
  shift
  set -m
  (
    begin=$(centiseconds)
    "$@" > "$log" 2>&1
    code=$?
    echo $(( $(centiseconds) - begin )) > "$log.cs"
    exit "$code"
  ) &
  set +m
  pids+=($!)
}

# report CODE [CS]: a check's verdict, and its time when it has one. A check
# that exits 77 had no saved answers to run on (test/fixtures-dir.sh).
skipped=0
report() {
  local took=${2:+ ($(printf '%d.%ds' $(($2 / 100)) $(($2 % 100 / 10))))}
  if [ "$1" -eq 0 ]; then echo "   ok$took"
  elif [ "$1" -eq 77 ]; then echo "   skipped$took"; skipped=$((skipped + 1))
  else echo "   FAILED$took"; status=1; fi
}
run() {
  echo "== $1"
  shift
  "$@"
  report $?
}

# saved_tests: the rules read against the saved answers, when there are any.
saved_tests() {
  local why
  why=$(test/fixtures-dir.sh 2>&1 > /dev/null) || { echo "SKIP saved.test.js: $why"; return 77; }
  bun test test/saved.test.js
}

# validate_clone: omarchy plugin validate on what a clone of this checkout
# holds: the tracked files as they are here, an uncommitted edit included,
# never an ignored one (out/, docs/, AGENTS.md, test/fixtures/). Links stay
# links, so a tracked one still fails.
validate_clone() {
  local tree code file
  tree=$(mktemp -d)
  git ls-files -z | while IFS= read -r -d '' file; do
    [[ -e $file || -L $file ]] && printf '%s\0' "$file"
  done | tar -c --null -T - | tar -x -C "$tree"
  (cd "$tree" && omarchy plugin validate .)
  code=$?
  rm -rf "$tree"
  return "$code"
}

# Longest first: the suite takes as long as the renders or the range harness.
start "offscreen renders" bash test/qml/render.sh
start "shared range harness" bash test/qml/range.sh
start "window search harness" bash test/qml/window-search.sh
start "window adds harness" bash test/qml/window-adds.sh
start "window motion harness" bash test/qml/window-motion.sh
start "fetch policy harness" bash test/qml/fetch.sh
start "named watchlists harness" bash test/qml/lists.sh
start "window rows harness" bash test/qml/window-rows.sh
start "pointer harness" bash test/qml/pointer.sh
start "popup harness" bash test/qml/popup.sh
start "popup motion harness" bash test/qml/popup-motion.sh
start "keys harness" bash test/qml/keys.sh
start "nothing-jumps layout harness" bash test/qml/layout.sh
start "quote queue harness" bash test/qml/run.sh
start "tophat guards (no screen)" bash test/tophat.sh self-check
start "Quickshell crash handling (stand-in)" bash test/qml/crash-check.sh
start "history harness" bash test/qml/history.sh
start "overnight harness" bash test/qml/overnight.sh
start "service harness" bash test/qml/service.sh

run "bun test (pure rules)" bun test test/model.test.js
run "bun test (saved answers)" saved_tests
run "source boundaries" bash test/boundaries.sh
run "qmllint (only the baseline in test/lint.sh)" bash test/lint.sh
run "qmllint gate self-check" bash test/lint.sh self-check
run "frame checker self-check" bun test/qml/frames.js self-check
run "launcher icon is the mark" bun test/mark-svg.js check
run "omarchy plugin validate (what a clone holds)" validate_clone
run "launcher entry validates" desktop-file-validate share/stonks.desktop

for i in "${!pids[@]}"; do
  wait "${pids[$i]}"
  code=$?
  echo "== ${labels[$i]}"
  cat "$logs/$i"
  report "$code" "$(cat "$logs/$i.cs" 2> /dev/null)"
done
if [ "$status" -ne 0 ]; then echo "SOME FAILED"
elif [ "$skipped" -gt 0 ]; then echo "PASSED, $skipped SKIPPED (no saved answers)"
else echo "ALL PASS"; fi
exit "$status"
