#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

# ── Colors ──────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

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
    echo -e "  ${BOLD}${label}:${RESET} ${DIM}0 (n/a)${RESET}"
    return
  fi

  local avg_fmt min_fmt max_fmt
  avg_fmt=$(format_duration "$avg")
  min_fmt=$(format_duration "$min")
  max_fmt=$(format_duration "$max")

  echo -e "  ${BOLD}${label}:${RESET} ${count}  ${DIM}avg ${avg_fmt} | min ${min_fmt} | max ${max_fmt}${RESET}"
}

echo ""
echo -e "  ${CYAN}${BOLD}ralph metrics${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

if [ ! -f "$RALPH_STATE" ]; then
  echo -e "  ${DIM}Finds no state file. Runs ./start.sh first.${RESET}"
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")
if [ "$agent_count" = "0" ]; then
  echo -e "  ${DIM}Finds no agents to inspect.${RESET}"
  echo ""
  exit 0
fi

now_epoch=$(date -u +%s)
metrics_json=$(jq --argjson now "$now_epoch" '
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
      total: ($agents | length),
      status: {
        running: ($agents | map(select(.status == "running")) | length),
        done: ($agents | map(select(.status == "done")) | length),
        failed: ($agents | map(select(.status == "failed")) | length)
      },
      types: {
        bigralph: ($agents | map(select(.type == "bigralph")) | length),
        productralph: ($agents | map(select(.type == "productralph")) | length),
        coderalph: ($agents | map(select(.type == "coderalph")) | length),
        other: ($agents | map(select(.type != "bigralph" and .type != "productralph" and .type != "coderalph")) | length)
      },
      durations: {
        done: stats($agents | map(select(.status == "done") | duration(.)) | map(select(. != null))),
        failed: stats($agents | map(select(.status == "failed") | duration(.)) | map(select(. != null))),
        running: stats($agents | map(select(.status == "running") | duration(.)) | map(select(. != null)))
      }
    }
' "$RALPH_STATE")

total=$(jq -r '.total' <<<"$metrics_json")
running=$(jq -r '.status.running' <<<"$metrics_json")
done=$(jq -r '.status.done' <<<"$metrics_json")
failed=$(jq -r '.status.failed' <<<"$metrics_json")

bigralph=$(jq -r '.types.bigralph' <<<"$metrics_json")
productralph=$(jq -r '.types.productralph' <<<"$metrics_json")
coderalph=$(jq -r '.types.coderalph' <<<"$metrics_json")
other=$(jq -r '.types.other' <<<"$metrics_json")

running_count=$(jq -r '.durations.running.count' <<<"$metrics_json")
running_avg=$(jq -r '.durations.running.avg' <<<"$metrics_json")
running_min=$(jq -r '.durations.running.min' <<<"$metrics_json")
running_max=$(jq -r '.durations.running.max' <<<"$metrics_json")

done_count=$(jq -r '.durations.done.count' <<<"$metrics_json")
done_avg=$(jq -r '.durations.done.avg' <<<"$metrics_json")
done_min=$(jq -r '.durations.done.min' <<<"$metrics_json")
done_max=$(jq -r '.durations.done.max' <<<"$metrics_json")

failed_count=$(jq -r '.durations.failed.count' <<<"$metrics_json")
failed_avg=$(jq -r '.durations.failed.avg' <<<"$metrics_json")
failed_min=$(jq -r '.durations.failed.min' <<<"$metrics_json")
failed_max=$(jq -r '.durations.failed.max' <<<"$metrics_json")

echo -e "  ${BOLD}Agents:${RESET} ${total} total"
echo -e "  ${BOLD}Status:${RESET} ${GREEN}${running}${RESET} running  ${DIM}${done}${RESET} done  ${RED}${failed}${RESET} failed"
echo -e "  ${BOLD}Types:${RESET} ${CYAN}${bigralph}${RESET} bigralph  ${YELLOW}${productralph}${RESET} productralph  ${DIM}${coderalph}${RESET} coderalph  ${DIM}${other}${RESET} other"
echo ""
echo -e "  ${BOLD}Durations:${RESET}"
format_stat_line "Running age" "$running_count" "$running_avg" "$running_min" "$running_max"
format_stat_line "Done" "$done_count" "$done_avg" "$done_min" "$done_max"
format_stat_line "Failed" "$failed_count" "$failed_avg" "$failed_min" "$failed_max"

echo ""
