#!/usr/bin/env bash
# SessionStart — imprime un resumen del estado del repo al iniciar la sesión.
# El output del hook se inyecta como contexto en la conversación.
set -euo pipefail

echo "## Estado del proyecto al iniciar"
echo ""

if [[ -d .git ]]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "- Branch: \`$BRANCH\` · Cambios sin commit: $CHANGES"
fi

# Último spec
LATEST_SPEC=""
if [[ -d memory/specs ]]; then
  LATEST_SPEC=$(ls -t memory/specs/*.md 2>/dev/null | head -1 || true)
fi
if [[ -n "$LATEST_SPEC" ]]; then
  echo "- Spec activo: \`$LATEST_SPEC\`"
fi

# Backlog pendiente
if [[ -f memory/backlog.md ]]; then
  PENDING=$(grep -c '^- \[ \]' memory/backlog.md 2>/dev/null || echo 0)
  [[ "$PENDING" -gt 0 ]] && echo "- Backlog pendiente: $PENDING ítem(s) en \`memory/backlog.md\`"
fi

# Última evaluación
if [[ -d memory/evaluations ]]; then
  LATEST_EVAL=$(ls -t memory/evaluations/*.md 2>/dev/null | head -1 || true)
  [[ -n "$LATEST_EVAL" ]] && echo "- Última evaluación: \`$LATEST_EVAL\`"
fi

echo ""
echo "_(Generado por .claude/hooks/session-start.sh — desactivable en settings.json)_"
exit 0
