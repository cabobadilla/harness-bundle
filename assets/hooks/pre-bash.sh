#!/usr/bin/env bash
# Blocks dangerous shell commands. Reads JSON from stdin, returns JSON decision.
set -euo pipefail
INPUT=$(cat)
CMD=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')

BLOCKED_PATTERNS=( 'rm -rf /' 'rm -rf ~' ':\(\)\{' 'curl[^|]*\|[^|]*sh' 'wget[^|]*\|[^|]*sh' 'sudo ' 'chmod 777' )

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qE "$pattern"; then
    cat <<HOOKEOF
{"decision": "block", "reason": "Comando bloqueado por harness: patrón peligroso ($pattern)"}
HOOKEOF
    exit 0
  fi
done
exit 0
