#!/usr/bin/env bash
#
# tests/e2e-scaffold.sh — Smoke test del scaffolder en modo no-interactivo.
# Verifica que init-harness crea la estructura esperada y que es idempotente.
# NO requiere ANTHROPIC_API_KEY (no llama a Claude). Para el test que SÍ
# invoca a Claude headless, ver tests/e2e-claude.sh.
#
# Uso:   ./tests/e2e-scaffold.sh
# Salida: 0 si todo OK, !=0 al primer fallo con detalle.

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "$0")/.." && pwd)"
BUNDLE="$SCRIPT_DIR"
TARGET="$(mktemp -d -t harness-e2e-XXXX)"

GREEN=$(tput setaf 2 2>/dev/null || echo "")
RED=$(tput setaf 1 2>/dev/null || echo "")
RESET=$(tput sgr0 2>/dev/null || echo "")

pass() { echo "${GREEN}✓${RESET} $*"; }
fail() { echo "${RED}✗${RESET} $*"; exit 1; }

cleanup() { rm -rf "$TARGET"; }
trap cleanup EXIT

echo "▸ Bundle: $BUNDLE"
echo "▸ Target: $TARGET"
echo

# ─── Run 1 (non-interactive, todos los opcionales OFF) ─────────────────────
echo "▸ Corrida 1: scaffolder no-interactivo (deploy=cloudflare, git=no)"
HARNESS_PROJECT_NAME="e2e-demo" \
HARNESS_MISSION="App de notas con tags para usuario individual" \
HARNESS_PROJECT_TYPE="Personal" \
HARNESS_ARCH="B" \
HARNESS_GIT="no" \
HARNESS_DEPLOY="cloudflare" \
HARNESS_MCP_GITHUB="no" \
HARNESS_MCP_POSTGRES="no" \
HARNESS_HOOK_ON_STOP="yes" \
HARNESS_HOOK_PRE_BASH="yes" \
HARNESS_HOOK_USER_PROMPT_VALIDATOR="yes" \
HARNESS_HOOK_POST_EDIT_FORMAT="no" \
HARNESS_HOOK_SESSION_START="no" \
HARNESS_HOOK_SUBAGENT_STOP="no" \
"$BUNDLE/init-harness.sh" --non-interactive "$TARGET" > /tmp/e2e-run1.log 2>&1 || {
  cat /tmp/e2e-run1.log
  fail "init-harness falló"
}
pass "init-harness corrió sin error"

# ─── Asserts estructurales ─────────────────────────────────────────────────
EXPECTED_FILES=(
  "CLAUDE.md"
  "HARNESS.md"
  ".gitignore"
  ".env.example"
  ".mcp.json"
  ".claude/settings.json"
  ".claude/agents/planner.md"
  ".claude/agents/generator.md"
  ".claude/agents/evaluator.md"
  ".claude/commands/plan.md"
  ".claude/commands/config-stack.md"
  ".claude/commands/build.md"
  ".claude/commands/evaluate.md"
  ".claude/commands/ship.md"
  ".claude/hooks/on-stop.sh"
  ".claude/hooks/pre-bash.sh"
  ".claude/hooks/user-prompt-validator.sh"
  ".claude/skills/systematic-debugging/SKILL.md"
  ".claude/skills/test-driven-development/SKILL.md"
  ".claude/skills/verification-before-completion/SKILL.md"
  "memory/decisions.md"
  "memory/backlog.md"
  "docs/architecture.md"
)
for f in "${EXPECTED_FILES[@]}"; do
  [[ -f "$TARGET/$f" ]] || fail "Falta: $f"
done
pass "Todos los archivos esperados existen (${#EXPECTED_FILES[@]} files)"

# Hooks NO seleccionados deben NO existir
UNEXPECTED_FILES=(
  ".claude/hooks/post-edit-format.sh"
  ".claude/hooks/session-start.sh"
  ".claude/hooks/subagent-stop.sh"
  ".claude/hooks/freeze-guard.sh"
  ".claude/commands/freeze.md"
  ".claude/commands/unfreeze.md"
  ".claude/commands/configure-stack.md"
  ".git"
)
for f in "${UNEXPECTED_FILES[@]}"; do
  [[ ! -e "$TARGET/$f" ]] || fail "No debería existir: $f"
done
pass "Hooks/commands no seleccionados ausentes (${#UNEXPECTED_FILES[@]} checks)"

# settings.json NO debe contener Bash(git
if grep -q '"Bash(git ' "$TARGET/.claude/settings.json"; then
  fail "settings.json incluye permisos git, pero HARNESS_GIT=no"
fi
pass "settings.json sin permisos git (correcto, HARNESS_GIT=no)"

# .mcp.json debe tener cloudflare
grep -q '"cloudflare-bindings"' "$TARGET/.mcp.json" || fail ".mcp.json no incluye cloudflare-bindings"
pass ".mcp.json incluye cloudflare-bindings"

# CLAUDE.md debe tener DEPLOY_TARGET sustituido
grep -q 'Target:\*\* `cloudflare`' "$TARGET/CLAUDE.md" || fail "CLAUDE.md no tiene DEPLOY_TARGET=cloudflare"
pass "CLAUDE.md tiene deploy target = cloudflare"

# settings.json debe tener los 3 hooks seleccionados
for hook in on-stop pre-bash user-prompt-validator; do
  grep -q "$hook.sh" "$TARGET/.claude/settings.json" || fail "settings.json no menciona $hook.sh"
done
pass "settings.json incluye los 3 hooks seleccionados"

# settings.json NO debe mencionar los hooks deselectados
for hook in post-edit-format session-start subagent-stop; do
  ! grep -q "$hook.sh" "$TARGET/.claude/settings.json" || fail "settings.json menciona $hook.sh pero estaba OFF"
done
pass "settings.json sin hooks deselectados"

# ─── Run 2 (idempotencia) ──────────────────────────────────────────────────
echo
echo "▸ Corrida 2: idempotencia (mismas vars, sobre el mismo dir)"
HARNESS_PROJECT_NAME="e2e-demo" \
HARNESS_MISSION="App de notas con tags para usuario individual" \
HARNESS_DEPLOY="cloudflare" \
"$BUNDLE/init-harness.sh" --non-interactive "$TARGET" > /tmp/e2e-run2.log 2>&1 || {
  cat /tmp/e2e-run2.log
  fail "Segunda corrida rompió"
}
# La segunda corrida debe avisar "ya existe" y no romper
grep -q "ya existe" /tmp/e2e-run2.log || fail "Segunda corrida no muestra mensaje 'ya existe' — ¿se sobreescribió algo?"
pass "Idempotencia OK (segunda corrida omite existentes)"

# ─── Run 3 (git=yes) ───────────────────────────────────────────────────────
echo
echo "▸ Corrida 3: variante git=yes en directorio nuevo"
TARGET2="$(mktemp -d -t harness-e2e-git-XXXX)"
trap 'rm -rf "$TARGET" "$TARGET2"' EXIT
HARNESS_PROJECT_NAME="e2e-git" \
HARNESS_MISSION="Test" \
HARNESS_GIT="yes" \
HARNESS_DEPLOY="none" \
"$BUNDLE/init-harness.sh" --non-interactive "$TARGET2" > /tmp/e2e-run3.log 2>&1 || {
  cat /tmp/e2e-run3.log
  fail "Run 3 falló"
}
[[ -d "$TARGET2/.git" ]] || fail ".git no creado con HARNESS_GIT=yes"
grep -q '"Bash(git ' "$TARGET2/.claude/settings.json" || fail "settings.json no incluye permisos git"
pass "Variante git=yes: .git creado y permisos presentes en settings.json"

echo
echo "${GREEN}✓ E2E scaffold tests passed.${RESET}"
