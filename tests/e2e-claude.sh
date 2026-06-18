#!/usr/bin/env bash
#
# tests/e2e-claude.sh — Smoke test que invoca Claude Code en modo headless
# sobre un proyecto scaffoldeado. Verifica que el harness funciona end-to-end:
# scaffolding → /plan → /build genera código real.
#
# REQUISITOS:
#   - `claude` CLI instalado (npm install -g @anthropic-ai/claude-code)
#   - ANTHROPIC_API_KEY exportada
#
# COSTO ESTIMADO: ~$0.10-0.30 por corrida (Opus, 2 prompts cortos).
#
# Uso: ./tests/e2e-claude.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "$0")/.." && pwd)"
BUNDLE="$SCRIPT_DIR"

GREEN=$(tput setaf 2 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
YELLOW=$(tput setaf 3 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")

pass() { echo "${GREEN}✓${RESET} $*"; }
fail() { echo "${RED}✗${RESET} $*"; exit 1; }
warn() { echo "${YELLOW}⚠${RESET} $*"; }

# Prerequisitos
if ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI no encontrado — skip. Instalar con: npm install -g @anthropic-ai/claude-code"
  exit 0
fi
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  warn "ANTHROPIC_API_KEY no exportada — skip. Cuando tengas la key:"
  warn "  export ANTHROPIC_API_KEY=sk-ant-... && ./tests/e2e-claude.sh"
  exit 0
fi

TARGET="$(mktemp -d -t harness-e2e-claude-XXXX)"
cleanup() { echo "Target preservado para inspección: $TARGET"; }
trap cleanup EXIT

echo "▸ Scaffolding proyecto de prueba en $TARGET"
HARNESS_PROJECT_NAME="e2e-tip-calc" \
HARNESS_MISSION="Calculadora de propinas web simple: input monto y porcentaje, muestra total. Una sola página." \
HARNESS_PROJECT_TYPE="Personal" \
HARNESS_ARCH="B" \
HARNESS_GIT="yes" \
HARNESS_DEPLOY="none" \
"$BUNDLE/init-harness.sh" --non-interactive "$TARGET" > /tmp/e2e-claude-scaffold.log 2>&1 || {
  cat /tmp/e2e-claude-scaffold.log
  fail "Scaffolding falló"
}
pass "Scaffolding OK"

cd "$TARGET"

# ─── Step 1: /plan ─────────────────────────────────────────────────────────
echo "▸ Ejecutando /plan via Claude headless (~30s, ~$0.05)"
claude -p "/plan calculadora de propinas, una sola página, HTML/CSS/JS vanilla, sin frameworks" \
  --dangerously-skip-permissions \
  > /tmp/e2e-claude-plan.log 2>&1 || {
    tail -50 /tmp/e2e-claude-plan.log
    fail "/plan falló"
  }

# El planner debe haber escrito un spec
SPEC_COUNT=$(ls memory/specs/*.md 2>/dev/null | wc -l | tr -d ' ')
[[ "$SPEC_COUNT" -gt 0 ]] || fail "/plan no creó ningún spec en memory/specs/"
pass "/plan creó $SPEC_COUNT spec(s)"

# El planner debe haber actualizado la sección Stack en CLAUDE.md
if grep -q "<COMPLETAR" CLAUDE.md; then
  warn "CLAUDE.md aún tiene <COMPLETAR> — el planner puede no haber actualizado Stack"
else
  pass "CLAUDE.md sin <COMPLETAR> (planner actualizó secciones)"
fi

# ─── Step 2: /build ────────────────────────────────────────────────────────
echo "▸ Ejecutando /build via Claude headless (~60s, ~$0.15)"
claude -p "/build" \
  --dangerously-skip-permissions \
  > /tmp/e2e-claude-build.log 2>&1 || {
    tail -50 /tmp/e2e-claude-build.log
    fail "/build falló"
  }

# Debe haber generado algún archivo de código (html, js, py, etc.)
CODE_FILES=$(find . -type f \( -name "*.html" -o -name "*.js" -o -name "*.css" -o -name "*.py" -o -name "*.ts" -o -name "*.tsx" \) \
  -not -path "./node_modules/*" -not -path "./.git/*" -not -path "./.claude/*" -not -path "./memory/*" | wc -l | tr -d ' ')
[[ "$CODE_FILES" -gt 0 ]] || fail "/build no generó ningún archivo de código"
pass "/build generó $CODE_FILES archivo(s) de código"

echo
echo "${GREEN}✓ E2E Claude tests passed.${RESET}"
echo "  Target preservado para inspección: $TARGET"
echo "  Logs en /tmp/e2e-claude-*.log"
