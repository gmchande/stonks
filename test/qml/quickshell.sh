# The one way a test starts Quickshell (lib.sh's run_qs, render.sh), sourced
# by lib.sh and by crash-check.sh, which proves it with a stand-in.
#
# Quickshell's crash handler is off (QS_DISABLE_CRASH_HANDLER, Quickshell
# 0.3.1's src/launch/launch.cpp:154). On a crash it forks a child that dumps
# the core under its own pid, forks a crash reporter window (a bare
# `quickshell`) in the same process group, and starts Quickshell again in the
# crashed pid, which more than 10 s after launch reruns the harness from the
# top into the same log, where it can pass (src/crash/handler.cpp:58-159,
# src/launch/main.cpp:27-75). Off, a crash is the pid we started dying on its
# signal, its core filed under that pid.
#
# Each run is a process group of its own, which ends with the run, and
# everything it starts carries the run's mark (STONKS_RUN, procs.sh), so
# what left the group is found by the mark, never by name: the owner's shell
# and other runs are Quickshells too.
source "$(dirname "${BASH_SOURCE[0]}")/../procs.sh"
qs_mark="STONKS_RUN=$$-$(date +%s%N)"
qs_leader=""
qs_start=""
qs_watchdog=""
qs_code=0

# quickshell_run SECONDS LOG ARGS…: Quickshell ARGS into LOG, stopped after
# SECONDS. Sets qs_code: Quickshell's exit code, 124 on a timeout, or 128 and
# its signal on a death by one. Whatever ends it, its group and every
# process carrying the mark are stopped (quickshell_stop), and a FAIL line
# is added to LOG for a crash, a timeout, or a process that left the group.
quickshell_run() {
  local - secs=$1 log=$2 sig
  set +e
  shift 2
  rm -f "$log.timeout"
  set -m
  STONKS_RUN=${qs_mark#STONKS_RUN=} QS_DISABLE_CRASH_HANDLER=1 quickshell "$@" > "$log" 2>&1 < /dev/null &
  qs_leader=$!
  qs_start=$(start_of "$qs_leader")
  # The watchdog leads its own group too, so stopping it stops its sleep.
  ( sleep "$secs"; : > "$log.timeout"; signal_group TERM "$qs_leader" "$qs_start" "$qs_mark" ) &
  qs_watchdog=$!
  set +m
  wait "$qs_leader"
  qs_code=$?
  kill -- "-$qs_watchdog" 2> /dev/null
  wait "$qs_watchdog" 2> /dev/null
  qs_watchdog=""
  if [ -e "$log.timeout" ]; then
    qs_code=124
    echo "FAIL Quickshell timed out after $secs s" >> "$log"
  elif (( qs_code > 128 )); then
    sig=$(kill -l $((qs_code - 128)) 2> /dev/null)
    echo "FAIL Quickshell crashed: SIG$sig ($((qs_code - 128))), pid $qs_leader; its core dump: coredumpctl info $qs_leader" >> "$log"
  fi
  rm -f "$log.timeout"
  quickshell_stop "$log"
}

# quickshell_stop [LOG]: stops the run's group, then any process still
# carrying the mark, which left the group: that fails the run, named in LOG.
# The EXIT trap runs it too, so an interrupt leaves nothing behind.
quickshell_stop() {
  local - left i
  set +e
  [ -n "$qs_watchdog" ] && kill -- "-$qs_watchdog" 2> /dev/null
  [ -n "$qs_leader" ] || return 0
  if signal_group TERM "$qs_leader" "$qs_start" "$qs_mark"; then
    for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -g "$qs_leader" > /dev/null || break; sleep 0.2; done
    signal_group KILL "$qs_leader" "$qs_start" "$qs_mark"
  fi
  left=$(marked "$qs_mark")
  if [ -n "$left" ]; then
    kill -TERM $(cut -d' ' -f1 <<< "$left") 2> /dev/null
    sleep 0.2
    kill -KILL $(marked "$qs_mark" | cut -d' ' -f1) 2> /dev/null
    if [ -n "${1:-}" ]; then
      sed 's/^/FAIL a process Quickshell started left its group and outlived it (stopped): /' <<< "$left" >> "$1"
      (( qs_code != 0 )) || qs_code=1
    fi
  fi
  qs_leader=""
}
