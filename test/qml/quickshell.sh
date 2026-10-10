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
# and other runs are Quickshells too. The group's leader is a small shell,
# marked too, that starts Quickshell, reports how it ended, and then holds
# the group, shrugging off TERM, until the run kills it: so the group is
# known to be the run's until its last member is stopped, a child that
# cleared its environment included, and its number can't have passed to
# another group.
source "$(dirname "${BASH_SOURCE[0]}")/../procs.sh"
qs_mark="STONKS_RUN=$$-$(date +%s%N)"
qs_leader=""
qs_code=0

# quickshell_run SECONDS LOG ARGS…: Quickshell ARGS into LOG, stopped after
# SECONDS. Sets qs_code: Quickshell's exit code, 124 on a timeout, or 128 and
# its signal on a death by one. Whatever ends it, its group and every
# process carrying the mark are stopped (quickshell_stop), and a FAIL line
# is added to LOG for a crash, an unexpected exit, a timeout, or a process
# that left the group. A crash is a code over 128 whose rest names a signal.
# Exit 1 is a harness's own failure, which its FAIL lines already say; any
# other code, such as the 255 a file that fails to load gives, is an exit,
# which its log explains: no core to look for.
quickshell_run() {
  local - secs=$1 log=$2 fd pid sig
  set +e
  shift 2
  rm -f "$log.ended"
  mkfifo "$log.ended"
  exec {fd}<> "$log.ended"
  set -m
  STONKS_RUN=${qs_mark#STONKS_RUN=} bash -c '
    log=$1; shift
    QS_DISABLE_CRASH_HANDLER=1 quickshell "$@" > "$log" 2>&1 < /dev/null &
    trap "" TERM
    wait $!
    echo "$! $?" > "$log.ended"
    exec sleep infinity' _ "$log" "$@" &
  qs_leader=$!
  # The stop kills the leader on purpose; out of the job table, its end
  # prints no "Killed" notice. How Quickshell ended comes through the fifo.
  disown "$qs_leader"
  set +m
  if read -r -t "$secs" -u "$fd" pid qs_code; then
    if (( qs_code > 128 )) && sig=$(kill -l $((qs_code - 128)) 2> /dev/null) && [ -n "$sig" ]; then
      echo "FAIL Quickshell crashed: SIG$sig ($((qs_code - 128))), pid $pid; its core dump: coredumpctl info $pid" >> "$log"
    elif (( qs_code != 0 && qs_code != 1 )); then
      echo "FAIL Quickshell exited with code $qs_code; its log says why" >> "$log"
    fi
  else
    qs_code=124
    echo "FAIL Quickshell timed out after $secs s" >> "$log"
  fi
  quickshell_stop "$log"
  exec {fd}<&-
  rm -f "$log.ended"
}

# quickshell_stop [LOG]: stops the run's group, then any process still
# carrying the mark, which left the group: that fails the run, named in LOG.
# The EXIT trap runs it too, so an interrupt leaves nothing behind, one that
# comes before the leader is recorded too: the leader is then the marked
# process this shell started that leads its group.
quickshell_stop() {
  local - left pid i me=$BASHPID
  set +e
  [ -n "$qs_leader" ] || qs_leader=$(marked "$qs_mark" | while read -r pid _; do
    [ "$(ppid_of "$pid")" = "$me" ] && echo "$pid"; done | head -n 1)
  # The group is the run's while its leader carries the mark and leads it,
  # which it does until killed.
  if leads_marked "$qs_leader"; then
    kill -TERM -- "-$qs_leader" 2> /dev/null
    for i in $(seq 10); do [ "$(pgrep -g "$qs_leader" | wc -l)" -le 1 ] && break; sleep 0.2; done
    leads_marked "$qs_leader" && kill -KILL -- "-$qs_leader" 2> /dev/null
  fi
  qs_leader=""
  left=$(marked "$qs_mark")
  [ -n "$left" ] || return 0
  kill -TERM $(cut -d' ' -f1 <<< "$left") 2> /dev/null
  sleep 0.2
  kill -KILL $(marked "$qs_mark" | cut -d' ' -f1) 2> /dev/null
  if [ -n "${1:-}" ]; then
    sed 's/^/FAIL a process Quickshell started left its group and outlived it (stopped): /' <<< "$left" >> "$1"
    (( qs_code != 0 )) || qs_code=1
  fi
}

# quickshell_exit: what a script's EXIT trap runs. A second interrupt during
# it (test/all.sh's TERM after a Ctrl-C) must not cut the stop short.
quickshell_exit() {
  trap '' INT TERM
  quickshell_stop
}
leads_marked() { [ -n "$1" ] && [ "$(pgid_of "$1")" = "$1" ] && grep -qzx -- "$qs_mark" "/proc/$1/environ" 2> /dev/null; }
