#!/usr/bin/env bash
# freeze-guard.sh — PreToolUse(Edit|Write) hook.
# Blocks edits outside the dir recorded in .claude/.freeze (if it exists).
set -euo pipefail
FREEZE_FILE=".claude/.freeze"
[[ ! -f "$FREEZE_FILE" ]] && exit 0
SCOPE=$(tr -d '[:space:]' < "$FREEZE_FILE")
[[ -z "$SCOPE" ]] && exit 0
INPUT=$(cat)
TARGET=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
[[ -z "$TARGET" ]] && exit 0
REL_TARGET="${TARGET#$PWD/}"; REL_TARGET="${REL_TARGET#./}"
SCOPE_CLEAN="${SCOPE#./}"
case "$REL_TARGET" in
  "$SCOPE_CLEAN"|"$SCOPE_CLEAN"/*) exit 0 ;;
  *)
    cat <<HOOKEOF
{"decision": "block", "reason": "Freeze activo: edits restringidos a '$SCOPE_CLEAN'. Target '$REL_TARGET' fuera de scope. Usa /unfreeze para liberar."}
HOOKEOF
    exit 0 ;;
esac
