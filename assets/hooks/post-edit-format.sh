#!/usr/bin/env bash
# PostToolUse(Edit|Write) — auto-formatea el archivo recién editado
# si hay un formatter disponible para su extensión. Falla silenciosamente
# (no bloquea el flujo del agente).
set -euo pipefail
INPUT=$(cat)
FILE=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(.*\)"/\1/')
[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

case "$FILE" in
  *.py)
    if command -v ruff >/dev/null 2>&1; then ruff format "$FILE" >/dev/null 2>&1 || true
    elif command -v black >/dev/null 2>&1; then black -q "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss|*.html|*.md)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write "$FILE" >/dev/null 2>&1 || true
    elif [[ -f "node_modules/.bin/prettier" ]]; then
      ./node_modules/.bin/prettier --write "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" >/dev/null 2>&1 || true
    ;;
  *.rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$FILE" >/dev/null 2>&1 || true
    ;;
esac
exit 0
