#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

LIMIT=10
SINCE=""
STDOUT=0

usage() {
  echo "Usage: ./report.sh [--limit N] [--since YYYY-MM-DD] [--stdout]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --since)
      SINCE="$2"
      shift 2
      ;;
    --stdout)
      STDOUT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [ ! -f "$RALPH_STATE" ]; then
  echo "Finds no state file. Runs ./start.sh first."
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  echo "Finds no agents to inspect."
  exit 0
fi

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  echo "Invalid --limit value. Uses whole numbers."
  exit 1
fi

if [ -n "$SINCE" ] && ! [[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Invalid --since value. Uses YYYY-MM-DD."
  exit 1
fi

SINCE_TS=""
if [ -n "$SINCE" ]; then
  SINCE_TS="${SINCE}T00:00:00Z"
fi

REPORT_DIR="$RALPH_DIR/runs/reports"
mkdir -p "$REPORT_DIR"

stamp="$(date -u +%Y%m%d-%H%M%S)"
report_path="$REPORT_DIR/report-${stamp}.md"
now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
now_epoch="$(date -u +%s)"

to_epoch() {
  local ts="$1"
  if [ -z "$ts" ] || [ "$ts" = "null" ]; then
    echo ""
    return
  fi
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo ""
}

format_duration() {
  local total="$1"
  if [ -z "$total" ]; then
    echo ""
    return
  fi
  if [ "$total" -lt 0 ]; then
    total=0
  fi

  local days=$((total / 86400))
  local hours=$(((total % 86400) / 3600))
  local minutes=$(((total % 3600) / 60))
  local seconds=$((total % 60))

  local parts=""
  if [ "$days" -gt 0 ]; then
    parts="${days}d"
  fi
  if [ "$hours" -gt 0 ]; then
    parts="${parts}${parts:+ }${hours}h"
  fi
  if [ "$minutes" -gt 0 ]; then
    parts="${parts}${parts:+ }${minutes}m"
  fi
  if [ -z "$parts" ]; then
    parts="${seconds}s"
  fi

  echo "$parts"
}

format_stat_line() {
  local label="$1" count="$2" avg="$3" min="$4" max="$5"
  if [ "$count" = "0" ]; then
    echo "- Records ${label}: 0 (n/a)"
    return
  fi

  local avg_fmt min_fmt max_fmt
  avg_fmt=$(format_duration "$avg")
  min_fmt=$(format_duration "$min")
  max_fmt=$(format_duration "$max")

  echo "- Records ${label}: ${count} (avg ${avg_fmt}, min ${min_fmt}, max ${max_fmt})"
}

human_duration() {
  local start="$1" end="$2"
  local start_epoch end_epoch
  start_epoch=$(to_epoch "$start")
  end_epoch=$(to_epoch "$end")
  if [ -z "$start_epoch" ] || [ -z "$end_epoch" ]; then
    echo ""
    return
  fi
  format_duration "$((end_epoch - start_epoch))"
}

running_count=$(jq '[.agents[] | select(.status == "running")] | length' "$RALPH_STATE")
done_count=$(jq '[.agents[] | select(.status == "done")] | length' "$RALPH_STATE")
failed_count=$(jq '[.agents[] | select(.status == "failed")] | length' "$RALPH_STATE")

stats_json=$(jq --argjson now "$now_epoch" '
  def to_epoch($ts):
    if $ts == null or $ts == "" then null
    else ($ts | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime)
    end;
  def duration($agent):
    (to_epoch($agent.started_at)) as $start
    | (if $agent.status == "running" then $now else to_epoch($agent.ended_at) end) as $end
    | if $start == null or $end == null then null else ($end - $start) end;
  def stats($arr):
    if ($arr | length) == 0 then {count: 0, avg: null, min: null, max: null}
    else {
      count: ($arr | length),
      avg: ($arr | add / length | floor),
      min: ($arr | min),
      max: ($arr | max)
    } end;
  .agents as $agents
  | {
      types: {
        bigralph: ($agents | map(select(.type == "bigralph")) | length),
        productralph: ($agents | map(select(.type == "productralph")) | length),
        coderalph: ($agents | map(select(.type == "coderalph")) | length),
        other: ($agents | map(select(.type != "bigralph" and .type != "productralph" and .type != "coderalph")) | length)
      },
      durations: {
        done: stats($agents | map(select(.status == "done") | duration(.)) | map(select(. != null))),
        failed: stats($agents | map(select(.status == "failed") | duration(.)) | map(select(. != null)))
      }
    }
' "$RALPH_STATE")

bigralph_count=$(jq -r '.types.bigralph' <<<"$stats_json")
productralph_count=$(jq -r '.types.productralph' <<<"$stats_json")
coderalph_count=$(jq -r '.types.coderalph' <<<"$stats_json")
other_count=$(jq -r '.types.other' <<<"$stats_json")

done_stat_count=$(jq -r '.durations.done.count' <<<"$stats_json")
done_stat_avg=$(jq -r '.durations.done.avg' <<<"$stats_json")
done_stat_min=$(jq -r '.durations.done.min' <<<"$stats_json")
done_stat_max=$(jq -r '.durations.done.max' <<<"$stats_json")

failed_stat_count=$(jq -r '.durations.failed.count' <<<"$stats_json")
failed_stat_avg=$(jq -r '.durations.failed.avg' <<<"$stats_json")
failed_stat_min=$(jq -r '.durations.failed.min' <<<"$stats_json")
failed_stat_max=$(jq -r '.durations.failed.max' <<<"$stats_json")

stale_ids=()
for id in $(jq -r '.agents[] | select(.status == "running") | .id' "$RALPH_STATE"); do
  pid=$(ralph_get "$id" pid)
  if ! kill -0 "$pid" 2>/dev/null; then
    stale_ids+=("$id")
  fi
done

running_entries=$(jq -r \
  --argjson limit "$LIMIT" \
  '
    .agents
    | to_entries
    | map(select(.value.status == "running"))
    | sort_by(.value.started_at // "")
    | .[0:$limit]
    | .[]
    | [.key, .value.type, (.value.started_at // ""), .value.task]
    | @tsv
  ' "$RALPH_STATE")

recent_entries=$(jq -r \
  --arg since "$SINCE_TS" \
  --argjson limit "$LIMIT" \
  '
    .agents
    | to_entries
    | map(select(.value.status != "running"))
    | map(select(.value.ended_at != null and .value.ended_at != ""))
    | (if $since == "" then . else map(select(.value.ended_at >= $since)) end)
    | sort_by(.value.ended_at)
    | reverse
    | .[0:$limit]
    | .[]
    | [.key, .value.type, .value.status, (.value.started_at // ""), (.value.ended_at // ""), .value.task]
    | @tsv
  ' "$RALPH_STATE")

{
  echo "# Ralph Report — ${now_ts}"
  echo ""
  echo "## Summary"
  echo "- Records total agents: ${agent_count}"
  echo "- Records running agents: ${running_count}"
  echo "- Records done agents: ${done_count}"
  echo "- Records failed agents: ${failed_count}"
  echo "- Records agent types: bigralph ${bigralph_count}, productralph ${productralph_count}, coderalph ${coderalph_count}, other ${other_count}"
  echo "- Records stale running agents: ${#stale_ids[@]}"
  echo ""
  echo "## Type breakdown"
  echo "- Records bigralph agents: ${bigralph_count}"
  echo "- Records productralph agents: ${productralph_count}"
  echo "- Records coderalph agents: ${coderalph_count}"
  echo "- Records other agents: ${other_count}"
  echo ""
  echo "## Duration stats"
  format_stat_line "done durations" "$done_stat_count" "$done_stat_avg" "$done_stat_min" "$done_stat_max"
  format_stat_line "failed durations" "$failed_stat_count" "$failed_stat_avg" "$failed_stat_min" "$failed_stat_max"
  echo ""
  echo "## Running agents"
  if [ -z "$running_entries" ]; then
    echo "Finds no running agents."
  else
    echo "| ID | Type | Started (UTC) | Duration | Task |"
    echo "| --- | --- | --- | --- | --- |"
    while IFS=$'\t' read -r id type started task; do
      duration="$(human_duration "$started" "$now_ts")"
      echo "| ${id} | ${type} | ${started} | ${duration} | ${task} |"
    done <<< "$running_entries"
  fi
  echo ""
  if [ -n "$SINCE" ]; then
    echo "## Recent completions since ${SINCE}"
  else
    echo "## Recent completions"
  fi
  if [ -z "$recent_entries" ]; then
    echo "Finds no completed agents in the window."
  else
    echo "| ID | Type | Status | Ended (UTC) | Duration | Task |"
    echo "| --- | --- | --- | --- | --- | --- |"
    while IFS=$'\t' read -r id type status started ended task; do
      duration="$(human_duration "$started" "$ended")"
      echo "| ${id} | ${type} | ${status} | ${ended} | ${duration} | ${task} |"
    done <<< "$recent_entries"
  fi
  echo ""
  echo "## Stale running agents"
  if [ "${#stale_ids[@]}" -eq 0 ]; then
    echo "Finds no stale running agents."
  else
    for stale_id in "${stale_ids[@]}"; do
      echo "- Records stale agent: ${stale_id}"
    done
  fi
} > "$report_path"

if [ "$STDOUT" -eq 1 ]; then
  cat "$report_path"
else
  echo "Writes report to ${report_path}."
fi
