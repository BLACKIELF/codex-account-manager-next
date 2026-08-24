#!/bin/zsh
set -u
set -o pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

OUTPUT_DIR="${CAMNEXT_PHASE_ONE_OUTPUT_DIR:-$ROOT_DIR/build/phase-one}"
BIN="$ROOT_DIR/build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext"
DURATION_SECONDS="${DURATION_SECONDS:-28800}"
SAMPLE_INTERVAL_SECONDS="${SAMPLE_INTERVAL_SECONDS:-60}"
mkdir -p "$OUTPUT_DIR"

pid="$(pgrep -f "$BIN" | head -1 || true)"
launched=0
if [[ -z "$pid" ]]; then
  "$BIN" >"$OUTPUT_DIR/soak-app.log" 2>&1 &
  pid=$!
  launched=1
  sleep 2
fi

samples="$OUTPUT_DIR/soak-samples.csv"
print 'elapsedSeconds,rssKilobytes,cpuPercent' >"$samples"
start_epoch="$(date +%s)"
deadline=$((start_epoch + DURATION_SECONDS))
conclusion=pass

while (( $(date +%s) < deadline )); do
  if ! kill -0 "$pid" 2>/dev/null; then
    conclusion=fail
    break
  fi
  now="$(date +%s)"
  rss="$(ps -o rss= -p "$pid" | tr -d ' ' || print 0)"
  cpu="$(ps -o %cpu= -p "$pid" | tr -d ' ' || print 0)"
  print "$((now - start_epoch)),${rss:-0},${cpu:-0}" >>"$samples"
  sleep "$SAMPLE_INTERVAL_SECONDS"
done

end_epoch="$(date +%s)"
actual_duration=$((end_epoch - start_epoch))
sample_count="$(awk 'NR > 1 { count++ } END { print count + 0 }' "$samples")"
max_rss="$(awk -F, 'NR > 1 && $2 > max { max=$2 } END { print max + 0 }' "$samples")"
average_cpu="$(awk -F, 'NR > 1 { sum+=$3; count++ } END { if (count) printf "%.2f", sum/count; else print 0 }' "$samples")"

if (( launched == 1 )); then
  kill "$pid" 2>/dev/null || true
fi

cat >"$OUTPUT_DIR/soak.json" <<EOF
{
  "version": 1,
  "conclusion": "$conclusion",
  "durationSeconds": $actual_duration,
  "sampleCount": $sample_count,
  "maximumResidentKilobytes": $max_rss,
  "averageCPUPercent": $average_cpu
}
EOF

print "Soak: $conclusion (${actual_duration}s, ${sample_count} samples)"
print "Result: $OUTPUT_DIR/soak.json"
[[ "$conclusion" == "pass" ]] || exit 1
