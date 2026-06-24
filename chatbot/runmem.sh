#!/usr/bin/env bash
# runmem.sh — run a command while sampling memory to a TSV; print the peak afterward.
# Usage: ./runmem.sh [interval_sec] -- <command...>
#   ./runmem.sh 1 -- docker compose run --rm bot python -m scripts.reindex
#   ./runmem.sh 0.5 -- sleep 120     # or: log for 2 min while you exercise the bot in a browser
set -u

INT=1
if [ "${1:-}" != "--" ]; then INT="$1"; shift; fi
[ "${1:-}" = "--" ] && shift
if [ "$#" -eq 0 ]; then echo "usage: $0 [interval_sec] -- <command...>" >&2; exit 2; fi

LOG="$HOME/memlog-$(date +%Y%m%d-%H%M%S).tsv"
printf 'time\ttotal_MiB\tused_MiB\tavail_MiB\tswap_MiB\ttop_proc\ttop_rss_MiB\n' > "$LOG"

sample_once() {
  local mem top
  mem=$(awk '/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2}/^SwapTotal:/{st=$2}/^SwapFree:/{sf=$2}
             END{printf "%d\t%d\t%d\t%d", t/1024, (t-a)/1024, a/1024, (st-sf)/1024}' /proc/meminfo)
  top=$(ps -eo rss=,comm= --sort=-rss | awk 'NR==1{printf "%s\t%d", $2, $1/1024}')
  printf '%s\t%s\t%s\n' "$(date +%H:%M:%S)" "$mem" "$top"
}

( while :; do sample_once >> "$LOG"; sleep "$INT"; done ) &
SPID=$!

echo ">> sampling every ${INT}s -> $LOG"
echo ">> running: $*"
"$@"; RC=$?
kill "$SPID" 2>/dev/null; wait "$SPID" 2>/dev/null

echo ">> command exited rc=$RC"
awk -F'\t' 'NR>1{
    if($3>u){u=$3;ut=$1}
    if(m==""||$4<m){m=$4;mt=$1}
    if($5>sw)sw=$5
    if($7>tr){tr=$7;tp=$6}
  } END{
    print  "=== peak over the run ==="
    printf "peak used:        %d MiB   (at %s)\n", u, ut
    printf "min available:    %d MiB   (at %s)\n", m, mt
    printf "max swap used:    %d MiB\n", sw
    printf "biggest process:  %d MiB   (%s)\n", tr, tp
  }' "$LOG"
echo ">> full timeline saved: $LOG"
