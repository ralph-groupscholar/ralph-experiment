#!/usr/bin/env bash
set -e

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RALPH_DIR/state/helpers.sh"

OUTPUT=""
FORMAT=""
INCLUDE_NOTES=0

usage() {
  echo "Usage: ./graph.sh [--output PATH] [--format svg|png|pdf] [--notes]"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    --notes)
      INCLUDE_NOTES=1
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
  echo "Finds no agents to graph."
  exit 0
fi

if [ -n "$FORMAT" ]; then
  if [ -z "$OUTPUT" ]; then
    echo "Requires --output when --format is used."
    exit 1
  fi
  if ! command -v dot >/dev/null 2>&1; then
    echo "Finds no 'dot' binary. Installs Graphviz or skips --format."
    exit 1
  fi
  case "$FORMAT" in
    svg|png|pdf)
      ;;
    *)
      echo "Invalid --format value. Uses svg, png, or pdf."
      exit 1
      ;;
  esac
fi

dot_content=$(jq -r --argjson notes "$INCLUDE_NOTES" '
  def esc($s): ($s | gsub("\\\\"; "\\\\") | gsub("\""; "\\\""));
  def color($status):
    if $status == "running" then "lightgoldenrod1"
    elif $status == "done" then "palegreen2"
    elif $status == "failed" then "lightsalmon"
    else "lightgray"
    end;
  def label($agent; $notes):
    ($agent.id + "\\n" + $agent.type + " • " + $agent.status)
    + (if $notes == 1 then
        ("\\n"
         + ((if ($agent.note // "") != "" then $agent.note else "" end))
         + (if ((($agent.tags // []) | length) > 0) then
             ((if ($agent.note // "") != "" then " " else "" end)
              + "[" + (($agent.tags // []) | join(", ")) + "]")
           else "" end))
      else "" end);
  "digraph Ralph {\n  rankdir=TB;\n  node [shape=box, style=filled, color=gray40, fontname=\"Helvetica\", fontsize=10];"
  + "\n"
  + (.agents
     | to_entries
     | map("  \"" + (esc(.key)) + "\" [label=\"" + (label(.value; $notes) | esc) + "\", fillcolor=\"" + (color(.value.status)) + "\"];" )
     | join("\n"))
  + "\n"
  + (.agents
     | to_entries
     | map(select(.value.parent != null) | "  \"" + (esc(.value.parent)) + "\" -> \"" + (esc(.key)) + "\";")
     | join("\n"))
  + "\n}\n"
' "$RALPH_STATE")

if [ -n "$FORMAT" ]; then
  tmpfile=$(mktemp)
  printf "%s" "$dot_content" > "$tmpfile"
  dot -T"$FORMAT" "$tmpfile" -o "$OUTPUT"
  rm -f "$tmpfile"
  echo "Writes graph output to ${OUTPUT}."
  exit 0
fi

if [ -n "$OUTPUT" ]; then
  printf "%s" "$dot_content" > "$OUTPUT"
  echo "Writes graph output to ${OUTPUT}."
  exit 0
fi

printf "%s" "$dot_content"
