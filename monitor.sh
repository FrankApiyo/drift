#!/usr/bin/env bash
# Shows how many Drift processes are running and samples their CPU and memory.
#   ./monitor.sh             5 samples, 1 second apart (the first is dropped)
#   ./monitor.sh 10 60       10 samples, 60 seconds apart
set -euo pipefail

samples="${1:-5}"
if [[ "$samples" -lt 2 ]]; then
  echo "Need at least 2 samples; top's first one has no CPU figure yet." >&2
  exit 64
fi
interval="${2:-1}"
pids="$(pgrep -x -U "$(id -u)" Drift || true)"
count="$(printf '%s' "$pids" | grep -c . || true)"

echo "Drift processes running: $count"
if [[ "$count" -eq 0 ]]; then
  exit 1
fi
if [[ "$count" -gt 1 ]]; then
  echo "Warning: more than one Drift is running" >&2
fi

pid_args=()
for pid in $pids; do pid_args+=(-pid "$pid"); done
top -l "$samples" -s "$interval" "${pid_args[@]}" -stats pid,cpu,mem,threads \
  | awk '/^PID/ { header = $0; next }
         # The first row per process always reads 0% (nothing to compare against yet).
         header && NF >= 3 && $1 ~ /^[0-9]+$/ { if (seen[$1]++ == 0) next; print; n++; cpu += $2 }
         END { if (n) printf "Average CPU: %.2f%% over %d samples\n", cpu / n, n }'
