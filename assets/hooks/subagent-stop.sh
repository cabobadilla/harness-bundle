#!/usr/bin/env bash
# SubagentStop — registra el cierre de un subagente con timestamp + tipo,
# para tener trazabilidad de qué corrió cuándo (útil para debugging del harness).
set -euo pipefail
DATE=$(date +%Y-%m-%d-%H%M%S)
LOG_DIR="memory/sessions"
mkdir -p "$LOG_DIR"
INPUT=$(cat)
SUBAGENT=$(echo "$INPUT" | grep -oE '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"subagent_type"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
[[ -z "$SUBAGENT" ]] && SUBAGENT="unknown"
echo "[$DATE] subagent=$SUBAGENT" >> "$LOG_DIR/subagents.log"
exit 0
