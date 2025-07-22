#!/usr/bin/env bash

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

FORMAT="csv"
STATUS_FILTER=""
TYPE_FILTER=""
LIMIT=0
DESC=0
OUTPUT=""

usage() {
  echo "Usage: ./export.sh [--format csv|json] [--status running|done|failed] [--type bigralph|productralph|coderalph] [--limit N] [--latest] [--output path]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --status)
      STATUS_FILTER="$2"
      shift 2
      ;;
    --type)
      TYPE_FILTER="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --latest)
      DESC=1
      shift
      ;;
    --output)
      OUTPUT="$2"
      shift 2
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

case "$FORMAT" in
  csv|json) ;;
  *)
    echo "Finds unsupported format: $FORMAT"
    exit 1
    ;;
esac

csv_to_json_array() {
  local input="$1"
  if [ -z "$input" ]; then
    echo "null"
    return
  fi
  printf "%s" "$input" | tr ',' '\n' | jq -R -s 'split("\n")[:-1]'
}

if [ ! -f "$RALPH_STATE" ]; then
  echo ""
  echo -e "  Finds no state file. Runs ./start.sh first."
  echo ""
  exit 0
fi

agent_count=$(jq '.agents | length' "$RALPH_STATE")

if [ "$agent_count" = "0" ]; then
  echo ""
  echo -e "  Finds no agents running. Starts with ./start.sh"
  echo ""
  exit 0
fi

status_json="$(csv_to_json_array "$STATUS_FILTER")"
type_json="$(csv_to_json_array "$TYPE_FILTER")"
now_epoch=$(date -u +%s)

entry_count=$(jq -r \
  --argjson statuses "$status_json" \
  --argjson types "$type_json" \
  --argjson limit "$LIMIT" \
  --argjson desc "$DESC" \
  '
  .agents
  | to_entries
  | map(select(
      ($statuses == null or ($statuses | index(.value.status) != null))
      and ($types == null or ($types | index(.value.type) != null))
    ))
  | sort_by(.value.started_at // "")
  | (if $desc == 1 then reverse else . end)
  | (if $limit > 0 then .[:$limit] else . end)
  | length
' "$RALPH_STATE")

if [ "$entry_count" = "0" ]; then
  echo ""
  echo -e "  Finds no agents for the provided filters."
  echo ""
  exit 0
fi

ensure_output_path() {
  local target="$1"
  if [ -z "$target" ]; then
    return 0
  fi
  local dir
  dir="$(dirname "$target")"
  if [ ! -d "$dir" ]; then
    echo "Finds no output directory: $dir"
    exit 1
  fi
}

write_output() {
  if [ -n "$OUTPUT" ]; then
    "$@" > "$OUTPUT"
    echo ""
    echo "  Writes export to $OUTPUT"
    echo ""
  else
    "$@"
  fi
}

export_json() {
  jq \
    --argjson statuses "$status_json" \
    --argjson types "$type_json" \
    --argjson limit "$LIMIT" \
    --argjson desc "$DESC" \
    --argjson now "$now_epoch" \
    '
    def epoch(ts):
      if ts == null or ts == "" then null else (ts | fromdateiso8601) end;
    def end_epoch(status; ended_at):
      if ended_at != null and ended_at != "" then epoch(ended_at)
      elif status == "running" then $now
      else null end;
    def duration_s(started_at; status; ended_at):
      (epoch(started_at) as $s | end_epoch(status; ended_at) as $e | if $s == null or $e == null then null else ($e - $s) end);
    .agents
    | to_entries
    | map(select(
        ($statuses == null or ($statuses | index(.value.status) != null))
        and ($types == null or ($types | index(.value.type) != null))
      ))
    | sort_by(.value.started_at // "")
    | (if $desc == 1 then reverse else . end)
    | (if $limit > 0 then .[:$limit] else . end)
    | map({
        id: .key,
        type: .value.type,
        status: .value.status,
        task: .value.task,
        started_at: (.value.started_at // null),
        ended_at: (.value.ended_at // null),
        duration_seconds: duration_s(.value.started_at; .value.status; .value.ended_at),
        pid: .value.pid,
        parent: (.value.parent // null),
        children_count: (.value.children | length),
        workspace: (.value.workspace // null),
        archived_at: (.value.archived_at // null)
      })
  ' "$RALPH_STATE"
}

export_csv() {
  echo "id,type,status,task,started_at,ended_at,duration_seconds,pid,parent,children_count,workspace,archived_at"
  jq -r \
    --argjson statuses "$status_json" \
    --argjson types "$type_json" \
    --argjson limit "$LIMIT" \
    --argjson desc "$DESC" \
    --argjson now "$now_epoch" \
    '
    def epoch(ts):
      if ts == null or ts == "" then null else (ts | fromdateiso8601) end;
    def end_epoch(status; ended_at):
      if ended_at != null and ended_at != "" then epoch(ended_at)
      elif status == "running" then $now
      else null end;
    def duration_s(started_at; status; ended_at):
      (epoch(started_at) as $s | end_epoch(status; ended_at) as $e | if $s == null or $e == null then null else ($e - $s) end);
    .agents
    | to_entries
    | map(select(
        ($statuses == null or ($statuses | index(.value.status) != null))
        and ($types == null or ($types | index(.value.type) != null))
      ))
    | sort_by(.value.started_at // "")
    | (if $desc == 1 then reverse else . end)
    | (if $limit > 0 then .[:$limit] else . end)
    | .[]
    | [
        .key,
        .value.type,
        .value.status,
        (.value.task // ""),
        (.value.started_at // ""),
        (.value.ended_at // ""),
        (duration_s(.value.started_at; .value.status; .value.ended_at) // ""),
        (.value.pid // ""),
        (.value.parent // ""),
        (.value.children | length),
        (.value.workspace // ""),
        (.value.archived_at // "")
      ]
    | @csv
  ' "$RALPH_STATE"
}

ensure_output_path "$OUTPUT"

if [ "$FORMAT" = "json" ]; then
  write_output export_json
else
  write_output export_csv
fi
