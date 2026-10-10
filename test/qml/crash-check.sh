#!/usr/bin/env bash
# Proves quickshell.sh's handling with a stand-in Quickshell, no screen and
# no saved answers: a crash fails the run with a FAIL line naming its
# signal and core dump, a timeout and an interrupt too, an exit of 255 (a
# file that fails to load) reads as an exit, not a crash, an ordinary pass
# and failure read as before, and however a run ends nothing it started is
# still running, in its group or out of it, while a process the run did not
# start, and another run side by side, are left alone. The stand-in dies on
# a real signal with its core dump turned off (prctl PR_SET_DUMPABLE, 0:
# prctl(2)), so no core is written and no one is notified. Prints FAILED per
# miss.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$here/../procs.sh"
tmp=$(mktemp -d)
bystander=""
runs=()
# However this check ends, an interrupt included: the runs it started stop
# (each harness stops its own Quickshell), then its files go.
finish_check() {
  local run pid start
  trap '' INT TERM
  for run in "${runs[@]}"; do
    read -r pid start <<< "$run"
    leader_is "$pid" "$start" && kill -TERM -- "-$pid" 2> /dev/null
  done
  [ -n "$bystander" ] && kill "$bystander" 2> /dev/null
  wait
  rm -rf "$tmp"
}
trap finish_check EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
failed=0
miss() { echo "FAILED $*"; failed=1; }

# The stand-in: STANDIN says what it does. With STANDIN_LEAVE it first
# leaves a process in its group, one that clears its environment, mark and
# all, so only the group's stop can reach it; with STANDIN_LEAVE=both also
# one out of the group, as a detached start does. Their pids, and its own,
# go in STANDIN_DIR.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/quickshell" << 'EOF'
#!/usr/bin/python3
import ctypes, os, signal, subprocess, sys, time
mode, folder, leave = os.environ["STANDIN"], os.environ["STANDIN_DIR"], os.environ.get("STANDIN_LEAVE")
left = []
if leave:
    left.append(subprocess.Popen(["sleep", "300"], env={}).pid)
if leave == "both":
    left.append(subprocess.Popen(["sleep", "300"], start_new_session=True).pid)
open(folder + "/left", "w").write(" ".join(map(str, left)) + "\n")
open(folder + "/pid", "w").write("%d\n" % os.getpid())
if mode.endswith("-mid"):
    print("PASS a step before it", flush=True)
if mode.startswith(("abort", "segv")):
    ctypes.CDLL(None).prctl(4, 0)  # PR_SET_DUMPABLE: no core dump
    os.kill(os.getpid(), signal.SIGABRT if mode.startswith("abort") else signal.SIGSEGV)
if mode == "hang":
    time.sleep(600)
if mode == "exit255":
    sys.exit(255)
print("PASS the flow" if mode.startswith("pass") else "FAIL the flow", flush=True)
sys.exit(0 if mode.startswith("pass") else 1)
EOF
chmod +x "$tmp/bin/quickshell"
export PATH="$tmp/bin:$PATH"

# A process this check starts and no run marks: no cleanup may touch it.
setsid sleep 300 < /dev/null > /dev/null 2>&1 &
bystander=$!

alive() { kill -0 "$1" 2> /dev/null; }
# gone CASE: nothing CASE's run started is still running.
gone() {
  local pid dir=$tmp/$1
  for pid in $(cat "$dir/pid" "$dir/left" 2> /dev/null); do
    alive "$pid" && miss "$1: pid $pid is still running ($(tr '\0' ' ' < "/proc/$pid/cmdline"))"
  done
  [ -s "$dir/mark" ] && [ -n "$(marked "$(cat "$dir/mark")")" ] && miss "$1: marked processes still running: $(marked "$(cat "$dir/mark")")"
  alive "$bystander" || miss "$1: a process the run did not start was stopped"
}

# harness CASE MODE SECONDS [LEAVE] [EARLY]: one run in a harness of its
# own, as lib.sh runs it, in the background in a group of its own (job
# control, so INT is not ignored): its pid in h, its folder $tmp/CASE. With
# EARLY, the harness is sent TERM as it is about to record the group's
# leader, once the stand-in has started its children.
harness() {
  local dir=$tmp/$1
  mkdir -p "$dir"
  set -m
  STANDIN=$2 STANDIN_DIR=$dir STANDIN_LEAVE=${4:-} EARLY=${5:-} bash -c '
    source "$1/quickshell.sh"
    echo "$qs_mark" > "$3/mark"
    trap quickshell_exit EXIT; trap "exit 130" INT; trap "exit 143" TERM
    early() { local i; for i in $(seq 50); do [ -s "$STANDIN_DIR/left" ] && break; sleep 0.1; done; kill -TERM $$; }
    if [ -n "$EARLY" ]; then set -T; trap "[[ \$BASH_COMMAND == qs_leader=* ]] && early" DEBUG; fi
    quickshell_run "$2" "$3/log" -p nowhere
    echo "$qs_code" > "$3/code"' _ "$here" "$3" "$dir" < /dev/null > "$dir/out" 2>&1 &
  h=$!
  set +m
  runs+=("$h $(start_of "$h")")
}
# ran PID CASE: waits for CASE's harness; its code in code.
ran() { wait "$1" 2> /dev/null; code=$(cat "$tmp/$2/code" 2> /dev/null || echo none); }
within() { local i; for i in $(seq $(( $1 * 10 ))); do "${@:2}" && return 0; sleep 0.1; done; return 1; }

# A crash before any output, and one in the middle of a flow.
for case in abort segv-mid; do
  harness "$case" "$case" 20 both
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
  gone "$case"
done

# A hang, stopped at its time.
harness hang hang 1 both
ran "$h" hang
[ "$code" = 124 ] || miss "hang: code $code, not 124"
grep -qx 'FAIL Quickshell timed out after 1 s' "$tmp/hang/log" || miss "hang: no timeout line: $(cat "$tmp/hang/log")"
gone hang

# An exit of 255, as Quickshell gives for a file that fails to load: an exit
# pointing at its log, never a crash pointing at a core dump.
harness exit255 exit255 20
ran "$h" exit255
[ "$code" = 255 ] || miss "exit255: code $code, not 255"
[ "$(cat "$tmp/exit255/log")" = "FAIL Quickshell exited with code 255; its log says why" ] \
  || miss "exit255: not read as an exit: $(cat "$tmp/exit255/log")"
gone exit255

# An ordinary pass and an ordinary failure read as before: their own code,
# their own lines, nothing added. A pass whose child stays in its group is
# still a pass, and the child is stopped.
for case in pass fail pass-in; do
  leave=""; [ "$case" = pass-in ] && leave=in
  harness "$case" "$case" 20 "$leave"
  ran "$h" "$case"
  want=0; [ "$case" = fail ] && want=1
  [ "$code" = "$want" ] || miss "$case: code $code, not $want"
  [ "$(cat "$tmp/$case/log")" = "$([ "$case" = fail ] && echo 'FAIL the flow' || echo 'PASS the flow')" ] \
    || miss "$case: its log changed: $(cat "$tmp/$case/log")"
  gone "$case"
done

# An interrupt of a harness: INT as a terminal sends it, TERM as test/all.sh
# does, each to the harness's group, mid-run; and TERM the moment
# Quickshell has started, before the harness has recorded its group.
for signal in INT TERM; do
  harness "$signal" hang 60 both
  within 5 test -s "$tmp/$signal/left" || miss "$signal: the stand-in never started"
  kill -s "$signal" -- "-$h"
  wait "$h" 2> /dev/null
  gone "$signal"
done
harness early hang 60 both early
wait "$h" 2> /dev/null
sleep 0.5
gone early

# Side by side: one run crashes while another runs; the other's processes
# are left alone.
harness side-a hang 60 both; a=$h
within 5 test -s "$tmp/side-a/left" || miss "side by side: the first stand-in never started"
harness side-b abort 20 both; b=$h
ran "$b" side-b
gone side-b
for pid in $(cat "$tmp/side-a/pid" "$tmp/side-a/left"); do
  alive "$pid" || miss "side by side: the other run's pid $pid was stopped"
done
kill -TERM -- "-$a"
wait "$a" 2> /dev/null
gone side-a

(( failed )) && echo "Quickshell crash handling self-check FAILED" || echo "Quickshell crash handling self-check ok"
exit "$failed"
