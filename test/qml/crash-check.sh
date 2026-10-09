#!/usr/bin/env bash
# Proves quickshell.sh's handling with a stand-in Quickshell, no screen and
# no saved answers: a crash fails the run with a FAIL line naming its
# signal and core dump, a timeout and an interrupt too, an ordinary pass and
# failure read as before, and however a run ends nothing it started is
# still running, in its group or out of it, while a process the run did not
# start, and another run side by side, are left alone. The stand-in dies on
# a real signal with its core dump turned off (prctl PR_SET_DUMPABLE, 0:
# prctl(2)), so no core is written and no one is notified. Prints FAILED per
# miss.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
bystander=""
trap '[ -n "$bystander" ] && kill "$bystander" 2> /dev/null; rm -rf "$tmp"' EXIT
failed=0
miss() { echo "FAILED $*"; failed=1; }

# The stand-in: STANDIN says what it does; with STANDIN_LEAVE it first leaves
# one process in its group, as a crash reporter would, and one out of it, as
# a detached start does, their pids in STANDIN_DIR. A hanging one's process
# in its group clears its environment, mark and all, so only the group's
# stop can reach it; Quickshell still leads the group then.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/quickshell" << 'EOF'
#!/usr/bin/python3
import ctypes, os, signal, subprocess, sys, time
mode, folder = os.environ["STANDIN"], os.environ["STANDIN_DIR"]
if os.environ.get("STANDIN_LEAVE"):
    inside = subprocess.Popen(["sleep", "300"], env={} if mode == "hang" else None)
    outside = subprocess.Popen(["sleep", "300"], start_new_session=True)
    open(folder + "/left", "w").write("%d %d\n" % (inside.pid, outside.pid))
open(folder + "/pid", "w").write("%d\n" % os.getpid())
if mode.endswith("-mid"):
    print("PASS a step before it", flush=True)
if mode.startswith(("abort", "segv")):
    ctypes.CDLL(None).prctl(4, 0)  # PR_SET_DUMPABLE: no core dump
    os.kill(os.getpid(), signal.SIGABRT if mode.startswith("abort") else signal.SIGSEGV)
if mode == "hang":
    time.sleep(600)
print("PASS the flow" if mode == "pass" else "FAIL the flow", flush=True)
sys.exit(0 if mode == "pass" else 1)
EOF
chmod +x "$tmp/bin/quickshell"
export PATH="$tmp/bin:$PATH"

# A process this check starts and no run marks: no cleanup may touch it.
setsid sleep 300 < /dev/null > /dev/null 2>&1 &
bystander=$!

alive() { kill -0 "$1" 2> /dev/null; }
# gone CASE DIR: nothing the stand-in started is still running.
gone() {
  local pid
  for pid in $(cat "$2/pid" "$2/left" 2> /dev/null); do
    alive "$pid" && miss "$1: pid $pid is still running ($(tr '\0' ' ' < "/proc/$pid/cmdline"))"
  done
  alive "$bystander" || miss "$1: a process the run did not start was stopped"
}

# harness CASE MODE SECONDS [LEAVE]: one run in a harness of its own, as
# lib.sh runs it, in the background in a group of its own (job control, so
# INT is not ignored): its pid in h, its folder $tmp/CASE.
harness() {
  local dir=$tmp/$1
  mkdir -p "$dir"
  set -m
  STANDIN=$2 STANDIN_DIR=$dir STANDIN_LEAVE=${4:-} bash -c '
    source "$1/quickshell.sh"
    trap quickshell_stop EXIT; trap "exit 130" INT; trap "exit 143" TERM
    quickshell_run "$2" "$3/log" -p nowhere
    echo "$qs_code" > "$3/code"' _ "$here" "$3" "$dir" < /dev/null > "$dir/out" 2>&1 &
  h=$!
  set +m
}
# ran PID CASE: waits for CASE's harness; its code in code.
ran() { wait "$1" 2> /dev/null; code=$(cat "$tmp/$2/code" 2> /dev/null || echo none); }
within() { local i; for i in $(seq $(( $1 * 10 ))); do "${@:2}" && return 0; sleep 0.1; done; return 1; }

# A crash before any output, and one in the middle of a flow.
for case in abort segv-mid; do
  harness "$case" "$case" 20 leave
  ran "$h" "$case"
  sig=ABRT n=6; [ "$case" = segv-mid ] && sig=SEGV n=11
  pid=$(cat "$tmp/$case/pid" 2> /dev/null)
  [ "$code" = $((128 + n)) ] || miss "$case: code $code, not $((128 + n))"
  grep -qx "FAIL Quickshell crashed: SIG$sig ($n), pid $pid; its core dump: coredumpctl info $pid" "$tmp/$case/log" \
    || miss "$case: no FAIL line naming SIG$sig, pid $pid, and its core dump: $(cat "$tmp/$case/log")"
  outside=$(cut -d' ' -f2 "$tmp/$case/left" 2> /dev/null)
  grep -q "^FAIL a process Quickshell started left its group and outlived it (stopped): $outside " "$tmp/$case/log" \
    || miss "$case: the process that left the group is not named"
  [ "$case" = segv-mid ] && { head -n 1 "$tmp/$case/log" | grep -qx 'PASS a step before it' || miss "$case: the flow's line before the crash is lost"; }
  gone "$case" "$tmp/$case"
done

# A hang, stopped at its time.
harness hang hang 1 leave
ran "$h" hang
[ "$code" = 124 ] || miss "hang: code $code, not 124"
grep -qx 'FAIL Quickshell timed out after 1 s' "$tmp/hang/log" || miss "hang: no timeout line: $(cat "$tmp/hang/log")"
gone hang "$tmp/hang"

# An ordinary pass and an ordinary failure read as before: their own code,
# their own lines, nothing added.
for case in pass fail; do
  harness "$case" "$case" 20
  ran "$h" "$case"
  want=0; [ "$case" = fail ] && want=1
  [ "$code" = "$want" ] || miss "$case: code $code, not $want"
  [ "$(cat "$tmp/$case/log")" = "$([ "$case" = pass ] && echo 'PASS the flow' || echo 'FAIL the flow')" ] \
    || miss "$case: its log changed: $(cat "$tmp/$case/log")"
  gone "$case" "$tmp/$case"
done

# An interrupt of a harness: INT as a terminal sends it, TERM as test/all.sh
# does, each to the harness's group, mid-run.
for signal in INT TERM; do
  harness "$signal" hang 60 leave
  within 5 test -s "$tmp/$signal/left" || miss "$signal: the stand-in never started"
  kill -s "$signal" -- "-$h"
  wait "$h" 2> /dev/null
  gone "$signal" "$tmp/$signal"
done

# Side by side: one run crashes while another runs; the other's processes
# are left alone.
harness side-a hang 60 leave; a=$h
within 5 test -s "$tmp/side-a/left" || miss "side by side: the first stand-in never started"
harness side-b abort 20 leave; b=$h
ran "$b" side-b
gone side-b "$tmp/side-b"
for pid in $(cat "$tmp/side-a/pid" "$tmp/side-a/left"); do
  alive "$pid" || miss "side by side: the other run's pid $pid was stopped"
done
kill -TERM -- "-$a"
wait "$a" 2> /dev/null
gone side-a "$tmp/side-a"

(( failed )) && echo "Quickshell crash handling self-check FAILED" || echo "Quickshell crash handling self-check ok"
exit "$failed"
