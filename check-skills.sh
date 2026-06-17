#!/usr/bin/env bash
#
# check-skills.sh — Auditoría de skills/plugins globales en ~/.claude/
#
# Pensado para correrse INDEPENDIENTE del init-harness.sh:
#   • ANTES del bootstrap → verifica que el entorno esté limpio.
#   • DESPUÉS del bootstrap → confirma que nada se "encendió" por accidente.
#
# Por default solo REPORTA (no modifica nada). Las acciones destructivas
# son opt-in con --suggest (imprime comandos sin correrlos) o --interactive
# (pregunta uno a uno antes de ejecutar).
#
# Veredictos según §12 de harness_strategy.md.
#
# Uso:
#   Desde el bundle (no instalado global):
#     ./check-skills.sh [--suggest|--interactive|--help]
#
#   Si lo instalaste global con install-global.sh, desde CUALQUIER directorio:
#     check-skills [--suggest|--interactive|--help]
#     (sin `.sh` y sin `./` — es un symlink en ~/.local/bin/)
#
# Modos:
#   (sin args)       solo reporta, no modifica nada
#   --suggest        imprime comandos `claude plugin ...` sin correrlos
#   --interactive    pregunta uno a uno antes de ejecutar (con backup automático)
#   --help           esta ayuda
#
# Requiere: bash 3.2+, grep, sed, awk (BSD ok). Nada de jq/python/node.
#

set -euo pipefail

# ─── Colores ───────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$(tput bold); RESET=$(tput sgr0)
  GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); BLUE=$(tput setaf 4)
  RED=$(tput setaf 1); GREY=$(tput setaf 8 2>/dev/null || echo "")
else
  BOLD=""; RESET=""; GREEN=""; YELLOW=""; BLUE=""; RED=""; GREY=""
fi
say()   { echo -e "${BLUE}▸${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
err()   { echo -e "${RED}✗${RESET} $*" >&2; }
title() { echo -e "\n${BOLD}$*${RESET}"; }

# ─── Argumentos ────────────────────────────────────────────────────────────
MODE="report"
for arg in "$@"; do
  case "$arg" in
    --suggest)     MODE="suggest" ;;
    --interactive) MODE="interactive" ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *) err "Argumento desconocido: $arg (usa --help)"; exit 2 ;;
  esac
done

# ─── Paths ─────────────────────────────────────────────────────────────────
CLAUDE_DIR="${HOME}/.claude"
SETTINGS="${CLAUDE_DIR}/settings.json"
INSTALLED="${CLAUDE_DIR}/plugins/installed_plugins.json"
SKILLS_DIR="${CLAUDE_DIR}/skills"

# ─── Tabla de auditoría (§12 harness_strategy.md) ──────────────────────────
# Formato: nombre|veredicto|razón
# Veredictos: DROP, KEEP, DEFER
AUDIT_TABLE='
legalzoom|DROP|uso único; el caso ya se resolvió con código propio
superpowers|DROP|~50 skills auto-triggerables que contradicen el CLAUDE.md del harness
commit-commands|DROP|/ship del harness cubre commit/push/PR
github|DROP|usar MCP github en su lugar (mejor integración)
frontend-design|DROP|hay skill built-in equivalente; el planner lo lee puntual
playwright|KEEP|requerido por el evaluator Nivel B/C
railway|KEEP|plataforma de deploy real
cloudflare|KEEP|útil acotado; complementa skill cloudflare-deploy
skill-creator|KEEP|ROI claro mientras se construye el harness
ralph-loop|DEFER|arquitectura 3-agentes lo reemplaza; reevaluar en 1 semana
'

# Skills built-in del harness que SÍ son KEEP cuando viven en ~/.claude/skills/
HARNESS_SKILLS='systematic-debugging test-driven-development verification-before-completion'

verdict_for() {
  local name="$1"
  echo "$AUDIT_TABLE" | awk -F'|' -v n="$name" '$1==n {print $2"|"$3; exit}'
}

# ─── Validación de paths ───────────────────────────────────────────────────
if [[ ! -d "$CLAUDE_DIR" ]]; then
  err "No se encontró $CLAUDE_DIR. ¿Está Claude Code instalado?"
  exit 1
fi

title "🔎  Pre/post-flight: auditoría de ~/.claude/"
echo "  Modo: $MODE   ·   Estrategia: §12 de harness_strategy.md"

# ─── 1) Skills globales en ~/.claude/skills/ ───────────────────────────────
title "🧠  Skills globales (~/.claude/skills/)"
if [[ ! -d "$SKILLS_DIR" ]]; then
  ok "No hay carpeta skills/ — entorno limpio."
else
  declare -i s_keep=0 s_unknown=0
  for d in "$SKILLS_DIR"/*/; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    if echo " $HARNESS_SKILLS " | grep -q " $name "; then
      ok "$name   ${GREY}— skill del harness (systematic/TDD/verification)${RESET}"
      s_keep=$((s_keep+1))
    else
      warn "$name   ${GREY}— no está en el set canónico, revisión manual${RESET}"
      s_unknown=$((s_unknown+1))
    fi
  done
  echo "  Total: $s_keep canónicas · $s_unknown a revisar"
fi

# ─── 2) Plugins instalados (~/.claude/plugins/installed_plugins.json) ──────
title "🔌  Plugins instalados (installed_plugins.json)"
if [[ ! -f "$INSTALLED" ]]; then
  ok "No hay plugins instalados — entorno limpio."
  INSTALLED_LIST=""
else
  INSTALLED_LIST=$(grep -E '^[[:space:]]*"[^"]+@[^"]+"[[:space:]]*:' "$INSTALLED" \
    | sed -E 's/^[[:space:]]*"([^@]+)@([^"]+)".*/\1|\2/')
  if [[ -z "$INSTALLED_LIST" ]]; then
    ok "No se detectaron plugins."
  fi
fi

# ─── 3) Plugins habilitados (settings.json → enabledPlugins) ───────────────
title "⚡  Plugins HABILITADOS (settings.json → enabledPlugins)"
ENABLED_LIST=""
if [[ -f "$SETTINGS" ]]; then
  # Extraer el bloque enabledPlugins { ... } y sacar los nombres.
  ENABLED_LIST=$(awk '
    /"enabledPlugins"[[:space:]]*:/ {flag=1; depth=0}
    flag {
      for (i=1; i<=length($0); i++) {
        c = substr($0,i,1)
        if (c=="{") depth++
        if (c=="}") { depth--; if (depth==0) { print; flag=0; exit } }
      }
      print
    }
  ' "$SETTINGS" \
    | grep -E '^[[:space:]]*"[^"]+@[^"]+"[[:space:]]*:[[:space:]]*true' \
    | sed -E 's/^[[:space:]]*"([^@]+)@([^"]+)".*/\1|\2/')
fi

if [[ -z "$ENABLED_LIST" ]]; then
  ok "Ningún plugin habilitado."
else
  echo "$ENABLED_LIST" | while IFS='|' read -r name marketplace; do
    [[ -z "$name" ]] && continue
    v=$(verdict_for "$name")
    if [[ -z "$v" ]]; then
      warn "$name@$marketplace   ${GREY}— no listado en §12, revisión manual${RESET}"
    else
      verdict="${v%%|*}"
      reason="${v#*|}"
      case "$verdict" in
        KEEP)  ok    "$name@$marketplace   ${GREY}— KEEP · $reason${RESET}" ;;
        DROP)  err   "$name@$marketplace   — DROP · $reason" ;;
        DEFER) warn  "$name@$marketplace   — DEFER · $reason" ;;
      esac
    fi
  done
fi

# ─── 4) Plugins instalados pero NO habilitados ─────────────────────────────
title "💤  Instalados pero NO habilitados"
if [[ -z "$INSTALLED_LIST" ]]; then
  ok "(nada)"
else
  any_dormant="no"
  echo "$INSTALLED_LIST" | while IFS='|' read -r name marketplace; do
    [[ -z "$name" ]] && continue
    if ! echo "$ENABLED_LIST" | grep -qE "^${name}\|"; then
      v=$(verdict_for "$name")
      if [[ -n "$v" && "${v%%|*}" == "DROP" ]]; then
        warn "$name@$marketplace   ${GREY}— instalado, no enabled. Considera DESINSTALAR (DROP).${RESET}"
      else
        echo "  ${GREY}• $name@$marketplace (deshabilitado)${RESET}"
      fi
      any_dormant="yes"
    fi
  done
  [[ "$any_dormant" == "no" ]] && ok "(nada — todos los instalados están habilitados)"
fi

# ─── 5) CLAUDE.md global: referencias a plugins externos ───────────────────
title "📜  ~/.claude/CLAUDE.md — referencias a plugins externos"
GLOBAL_CLAUDE="${CLAUDE_DIR}/CLAUDE.md"
if [[ -f "$GLOBAL_CLAUDE" ]]; then
  hits=$(grep -nE '(gstack|superpowers|ralph-loop|legalzoom|commit-commands)' "$GLOBAL_CLAUDE" || true)
  if [[ -n "$hits" ]]; then
    warn "Tu CLAUDE.md global referencia plugins. El harness pide CLAUDE.md sin contraprogramación:"
    echo "$hits" | sed "s/^/    /"
  else
    ok "Sin referencias problemáticas."
  fi
else
  ok "No hay CLAUDE.md global."
fi

# ─── 6) Sugerencias / acción ───────────────────────────────────────────────
DROPS=$(echo "$ENABLED_LIST" | while IFS='|' read -r name marketplace; do
  [[ -z "$name" ]] && continue
  v=$(verdict_for "$name")
  if [[ "${v%%|*}" == "DROP" ]]; then echo "$name@$marketplace"; fi
done; true)
DEFERS=$(echo "$ENABLED_LIST" | while IFS='|' read -r name marketplace; do
  [[ -z "$name" ]] && continue
  v=$(verdict_for "$name")
  if [[ "${v%%|*}" == "DEFER" ]]; then echo "$name@$marketplace"; fi
done; true)

title "📋  Resumen"
drops_n=$(echo "$DROPS"  | grep -c . 2>/dev/null || true); drops_n=${drops_n:-0}
defers_n=$(echo "$DEFERS" | grep -c . 2>/dev/null || true); defers_n=${defers_n:-0}
echo "  DROP encontrados (habilitados):  $drops_n"
echo "  DEFER encontrados (habilitados): $defers_n"

if [[ -z "$DROPS" && -z "$DEFERS" ]]; then
  ok "Entorno alineado con el harness. Sin acciones requeridas."
  exit 0
fi

# Backup helper (solo se crea cuando hay algo que sugerir/ejecutar).
do_backup() {
  local stamp; stamp=$(date +%Y%m%d-%H%M%S)
  cp "$SETTINGS" "${SETTINGS}.bak-${stamp}"
  ok "Backup: ${SETTINGS}.bak-${stamp}"
}

case "$MODE" in
  report)
    title "💡  Próximos pasos"
    echo "  Re-corre con ${BOLD}--suggest${RESET} para ver los comandos sugeridos."
    echo "  Re-corre con ${BOLD}--interactive${RESET} para confirmar y ejecutar uno a uno."
    echo "  (Backup automático de settings.json en cualquier modo de ejecución.)"
    ;;

  suggest)
    title "💡  Comandos sugeridos (NO se ejecutan)"
    [[ -n "$DROPS" ]] && echo "$DROPS" | while read -r p; do
      [[ -n "$p" ]] && echo "  claude plugin uninstall $p     ${GREY}# DROP${RESET}"
    done
    [[ -n "$DEFERS" ]] && echo "$DEFERS" | while read -r p; do
      [[ -n "$p" ]] && echo "  claude plugin disable   $p     ${GREY}# DEFER (no desinstalar todavía)${RESET}"
    done
    echo
    say "Backup recomendado antes de ejecutar:"
    echo "  cp $SETTINGS ${SETTINGS}.bak-\$(date +%Y%m%d-%H%M%S)"
    ;;

  interactive)
    title "🤝  Confirmación uno a uno"
    do_backup
    confirm() {
      local prompt="$1"; local ans
      read -r -p "  $prompt [y/N]: " ans
      [[ "$ans" =~ ^[Yy]$ ]]
    }
    if [[ -n "$DROPS" ]]; then
      echo "$DROPS" | while read -r p; do
        [[ -z "$p" ]] && continue
        echo
        warn "DROP: $p"
        if confirm "¿Desinstalar?"; then
          if command -v claude >/dev/null 2>&1; then
            claude plugin uninstall "$p" || err "Falló uninstall de $p — revisar manualmente"
          else
            err "CLI 'claude' no encontrada en PATH — corre: claude plugin uninstall $p"
          fi
        else
          echo "  ${GREY}saltado${RESET}"
        fi
      done
    fi
    if [[ -n "$DEFERS" ]]; then
      echo "$DEFERS" | while read -r p; do
        [[ -z "$p" ]] && continue
        echo
        warn "DEFER: $p"
        if confirm "¿Deshabilitar (sin desinstalar)?"; then
          if command -v claude >/dev/null 2>&1; then
            claude plugin disable "$p" || err "Falló disable de $p — revisar manualmente"
          else
            err "CLI 'claude' no encontrada en PATH — corre: claude plugin disable $p"
          fi
        else
          echo "  ${GREY}saltado${RESET}"
        fi
      done
    fi
    ;;
esac

echo
ok "Auditoría completa."
