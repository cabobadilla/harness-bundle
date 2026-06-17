#!/usr/bin/env bash
#
# init-harness.sh — Bootstrap an Agent Harness for Claude Code (Opus 4.5+)
# Bundle edition v1d — DESACOPLADO: la lógica vive aquí, el contenido en assets/
#
# Architecture: Planner · Generator · Evaluator(ligero)
#   Nivel A (MVP):  Planner + Generator
#   Nivel B:        + Evaluator ligero (sin browser)
#   Nivel C:        + Evaluator Playwright — EN BACKLOG, no implementado
#
# Usage:
#   ./init-harness.sh                  # pregunta el directorio destino
#   ./init-harness.sh ./mi-proyecto    # usa el directorio dado
#
# Requiere: la carpeta assets/ junto a este script (es un bundle).
# Idempotente: omite archivos que ya existen.
#

set -euo pipefail

# ─── Localización del bundle (resolviendo symlinks para `init-harness` global) ─
# Si el script se invoca vía un symlink en PATH (ej. ~/.local/bin/init-harness),
# BASH_SOURCE[0] apunta al symlink, no al archivo real. Resolvemos la cadena
# manualmente porque BSD readlink (macOS) no tiene -f.
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  LINK_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$LINK_DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
ASSETS="$SCRIPT_DIR/assets"
BUNDLE_VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || echo "unknown")"

# ─── Colors ────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$(tput bold); RESET=$(tput sgr0)
  GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); BLUE=$(tput setaf 4); RED=$(tput setaf 1)
else
  BOLD=""; RESET=""; GREEN=""; YELLOW=""; BLUE=""; RED=""
fi
say()   { echo -e "${BLUE}▸${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
err()   { echo -e "${RED}✗${RESET} $*" >&2; }
title() { echo -e "\n${BOLD}$*${RESET}"; }

# ─── Validación del bundle ─────────────────────────────────────────────────
if [[ ! -d "$ASSETS" ]]; then
  err "No se encontró la carpeta assets/ junto a este script."
  err "Este script es parte de un bundle. Estructura esperada:"
  err "  harness-bundle/"
  err "  ├── init-harness.sh   (este archivo)"
  err "  ├── VERSION"
  err "  └── assets/           (FALTA)"
  exit 1
fi
for d in agents commands hooks templates; do
  if [[ ! -d "$ASSETS/$d" ]]; then
    err "Falta assets/$d/ — el bundle está incompleto."
    exit 1
  fi
done

# ─── Helpers de prompt ─────────────────────────────────────────────────────
ask() {
  local prompt="$1"; local default="${2:-}"; local var
  if [[ -n "$default" ]]; then
    read -r -p "  $prompt [$default]: " var; echo "${var:-$default}"
  else
    read -r -p "  $prompt: " var; echo "$var"
  fi
}

ask_choice() {
  local prompt="$1"; shift
  local options=("$@"); local count=${#options[@]}
  echo "  $prompt" >&2
  local i=1
  for opt in "${options[@]}"; do echo "    $i) $opt" >&2; ((i++)); done
  local choice idx
  read -r -p "  Elige [1]: " choice; choice="${choice:-1}"
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    idx=$((choice - 1))
  else
    local first; first=$(printf '%s' "$choice" | head -c1 | tr '[:lower:]' '[:upper:]')
    case "$first" in
      [A-Z]) idx=$(( $(printf '%d' "'$first") - 65 )) ;;
      *) idx=0 ;;
    esac
  fi
  (( idx < 0 || idx >= count )) && idx=0
  echo "${options[$idx]}"
}

ask_yn() {
  local prompt="$1"; local default="${2:-n}"
  local hint="[y/N]"; [[ "$default" == "y" ]] && hint="[Y/n]"
  read -r -p "  $prompt $hint: " ans; ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ─── Helpers de assets ─────────────────────────────────────────────────────
# Copia un asset a destino, sustituyendo placeholders {{VAR}} con sed.
# Uso: render_asset <ruta-relativa-en-assets> <ruta-destino>
render_asset() {
  local src="$ASSETS/$1"; local dst="$2"
  if [[ ! -f "$src" ]]; then err "Asset no encontrado: $1"; return 1; fi
  if [[ -e "$dst" ]]; then warn "$dst ya existe — se omite"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  # Sustituye placeholders conocidos. Los valores vienen de variables globales.
  sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME:-}|g" \
      -e "s|__PROJECT_NAME__|${PROJECT_NAME:-}|g" \
      -e "s|{{MISSION}}|${MISSION:-}|g" \
      -e "s|{{ARCH}}|${ARCH:-}|g" \
      -e "s|{{DATE}}|$(date +%Y-%m-%d)|g" \
      -e "s|{{BUNDLE_VERSION}}|${BUNDLE_VERSION}|g" \
      "$src" > "$dst"
  ok "Creado $dst"
}

# Copia un asset tal cual (sin sustitución), p.ej. hooks y skills.
copy_asset() {
  local src="$ASSETS/$1"; local dst="$2"
  if [[ ! -e "$src" ]]; then err "Asset no encontrado: $1"; return 1; fi
  if [[ -e "$dst" ]]; then warn "$dst ya existe — se omite"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  ok "Creado $dst"
}

# Lee el contenido de un fragmento (para inyectar en placeholders multilínea).
fragment() {
  cat "$ASSETS/templates/fragments/$1" 2>/dev/null || echo ""
}

# Reemplaza un placeholder {{KEY}} en un archivo por el contenido de un texto.
# Maneja multilínea de forma segura escribiendo el fragmento a un archivo
# temporal y leyéndolo con getline desde awk. Esto evita el bug de BSD awk
# (macOS) que rechaza valores -v con newlines literales.
inject_block() {
  local file="$1"; local key="$2"; local content="$3"
  local tmp frag
  tmp=$(mktemp)
  frag=$(mktemp)
  # Si content es vacío, frag queda vacío y getline retorna 0 (no inserta nada).
  printf '%s' "$content" > "$frag"
  awk -v key="{{$key}}" -v fragfile="$frag" '
    index($0, key) {
      while ((getline line < fragfile) > 0) print line
      close(fragfile)
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  rm -f "$frag"
}

# ─── Resolución del directorio destino ─────────────────────────────────────
TARGET_ARG="${1:-}"

title "🛠  Agent Harness Bootstrap — bundle $BUNDLE_VERSION (Opus 4.5+)"
say "Arquitectura: Planner · Generator · Evaluator"
echo

title "📁  Directorio del proyecto"
if [[ -n "$TARGET_ARG" ]]; then
  TARGET="$TARGET_ARG"
  say "Usando el directorio pasado como argumento: $TARGET"
else
  echo "  Este es el directorio DONDE SE CREARÁ el harness." >&2
  echo "  (Distinto del scope del MCP filesystem, que es avanzado y va en .mcp.json.example.)" >&2
  TARGET=$(ask "Ruta del proyecto (Enter = directorio actual)" ".")
fi
[[ ! -d "$TARGET" ]] && { mkdir -p "$TARGET"; ok "Creado directorio $TARGET"; }
cd "$TARGET"; TARGET_ABS=$(pwd)
say "Harness se creará en: $TARGET_ABS"

# ─── Preguntas ─────────────────────────────────────────────────────────────
title "📝  Información del proyecto"
echo "  El planner usa la MISIÓN como contexto inicial para generar el spec." >&2
echo "  Sé concreto: qué problema resolvés, para quién, qué hace único al proyecto." >&2
echo "  El stack NO se pregunta acá — lo define el planner en /plan y se afina con /configure-stack." >&2
PROJECT_NAME=$(ask "Nombre del proyecto" "$(basename "$TARGET_ABS")")
MISSION=$(ask "Misión (1-2 frases claras — qué hace, para quién)" "")

PROJECT_TYPE=$(ask_choice "Tipo de proyecto:" \
  "Personal" \
  "Cliente enterprise (estándar)" \
  "Cliente regulado (banca/salud/gov)")

title "🤖  Arquitectura de agentes"
echo "  A) MVP — Planner + Generator (lo más simple)" >&2
echo "  B) + Evaluator LIGERO — revisa código/output, sin browser (recomendado)" >&2
echo "  (Nivel C — Evaluator completo con Playwright — en el backlog, aún no implementado)" >&2
ARCH=$(ask_choice "¿Qué arquitectura?:" \
  "A - MVP (Planner + Generator)" \
  "B - Evaluator ligero (sin Playwright)")
WANT_EVALUATOR="no"; case "$ARCH" in B*) WANT_EVALUATOR="yes" ;; esac

title "🔌  MCPs"
MCP_GITHUB=$(ask_yn "¿Habilitar MCP github?" "y" && echo "yes" || echo "no")
MCP_POSTGRES=$(ask_yn "¿Habilitar MCP postgres?" "n" && echo "yes" || echo "no")

title "🛡  Guardrails"
ENABLE_HOOKS=$(ask_yn "¿Instalar hooks (pre-bash, on-stop, freeze-guard)?" "y" && echo "yes" || echo "no")

# ─── Confirmación ──────────────────────────────────────────────────────────
title "📂  Confirmación"
echo "  Crear en:       $TARGET_ABS"
echo "  Proyecto:       $PROJECT_NAME"
echo "  Tipo:           $PROJECT_TYPE"
echo "  Arquitectura:   $ARCH"
echo "  Evaluator:      $([ "$WANT_EVALUATOR" == "yes" ] && echo "ligero (sin browser)" || echo "no")"
echo "  Skills:         systematic-debugging, TDD, verification (copia local obligatoria)"
echo "  MCP github:     $MCP_GITHUB"
echo "  MCP postgres:   $MCP_POSTGRES"
echo "  Hooks:          $ENABLE_HOOKS"
echo "  Bundle:         $BUNDLE_VERSION"
echo
ask_yn "¿Proceder?" "y" || { warn "Cancelado por el usuario."; exit 0; }

# ─── Estructura base ───────────────────────────────────────────────────────
title "🏗  Creando estructura"
mkdir -p .claude/commands .claude/agents .claude/skills .claude/hooks
mkdir -p docs/decisions memory/specs memory/sessions
[[ "$WANT_EVALUATOR" == "yes" ]] && mkdir -p memory/evaluations
ok "Estructura base creada"

# ─── Templates base ────────────────────────────────────────────────────────
title "📄  Generando documentos base"
render_asset "templates/gitignore.tmpl"          ".gitignore"
render_asset "templates/env.example.tmpl"        ".env.example"
render_asset "templates/architecture.md.tmpl"    "docs/architecture.md"
render_asset "templates/adr-template.md.tmpl"    "docs/decisions/0000-template.md"
render_asset "templates/decisions.md.tmpl"       "memory/decisions.md"
render_asset "templates/mcp.json.example.tmpl"   ".mcp.json.example"

# ─── CLAUDE.md (con bloques condicionales) ─────────────────────────────────
render_asset "templates/CLAUDE.md.tmpl" "CLAUDE.md"
# Inyecta fragmentos multilínea
if [[ "$WANT_EVALUATOR" == "yes" ]]; then
  inject_block "CLAUDE.md" "EVAL_WORKFLOW" "$(fragment eval_workflow_B.txt)"
else
  inject_block "CLAUDE.md" "EVAL_WORKFLOW" "$(fragment eval_workflow_A.txt)"
fi
if [[ "$PROJECT_TYPE" == "Cliente regulado (banca/salud/gov)" ]]; then
  inject_block "CLAUDE.md" "COMPLIANCE_SECTION" "$(fragment compliance.txt)"
else
  inject_block "CLAUDE.md" "COMPLIANCE_SECTION" ""
fi

# ─── .mcp.json ─────────────────────────────────────────────────────────────
title "🔌  Generando .mcp.json"
MCP_ENTRIES=()
[[ "$MCP_GITHUB" == "yes" ]] && MCP_ENTRIES+=('"github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}" }
    }')
[[ "$MCP_POSTGRES" == "yes" ]] && MCP_ENTRIES+=('"postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": { "DATABASE_URL": "${DATABASE_URL}" }
    }')

if [[ -e .mcp.json ]]; then
  warn ".mcp.json ya existe — se omite (preserva customizaciones)"
else
  if [[ ${#MCP_ENTRIES[@]} -eq 0 ]]; then
    printf '{\n  "mcpServers": {}\n}\n' > .mcp.json
  else
    { echo "{"; echo '  "mcpServers": {'
      for i in "${!MCP_ENTRIES[@]}"; do
        printf '    %s' "${MCP_ENTRIES[$i]}"
        [[ $i -lt $((${#MCP_ENTRIES[@]} - 1)) ]] && echo "," || echo ""
      done
      echo "  }"; echo "}"
    } > .mcp.json
  fi
  ok "Creado .mcp.json"
fi

# ─── settings.json (permisos + hooks) ──────────────────────────────────────
title "🛡  Generando .claude/settings.json"
EXTRA_DENY=""
if [[ "$PROJECT_TYPE" == "Cliente regulado (banca/salud/gov)" ]]; then
  EXTRA_DENY=',
      "Read(./customer/**)",
      "Read(./payments/**)",
      "Edit(./customer/**)",
      "Write(./customer/**)",
      "Edit(./payments/**)",
      "Write(./payments/**)"'
fi
HOOKS_BLOCK=""
if [[ "$ENABLE_HOOKS" == "yes" ]]; then
  HOOKS_BLOCK=',
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": ".claude/hooks/pre-bash.sh" } ] },
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": ".claude/hooks/freeze-guard.sh" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": ".claude/hooks/on-stop.sh" } ] }
    ]
  }'
fi

if [[ -e .claude/settings.json ]]; then
  warn ".claude/settings.json ya existe — se omite (preserva permisos/hooks customizados)"
else
cat > .claude/settings.json <<JSONEOF
{
  "permissions": {
    "allow": [
      "Bash(git diff:*)",
      "Bash(git status:*)",
      "Bash(git log:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git restore:*)",
      "Bash(git checkout:*)",
      "Bash(git switch:*)",
      "Bash(git branch:*)",
      "Bash(git stash:*)",
      "Bash(git fetch:*)",
      "Bash(git merge:*)",
      "Bash(git rebase:*)",
      "Bash(git show:*)",
      "Bash(git remote:*)",
      "Bash(git tag:*)",
      "Bash(git config:*)",
      "Bash(git init:*)",
      "Bash(npm test:*)",
      "Bash(npm run:*)",
      "Bash(npm ci:*)",
      "Bash(pytest:*)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(mkdir:*)",
      "Bash(grep:*)",
      "Bash(find:*)",
      "Bash(touch:*)",
      "Bash(cp:*)",
      "Bash(mv:*)",
      "Read(./**)",
      "Edit(./**)",
      "Write(./**)"
    ],
    "ask": [
      "Bash(git push:*)",
      "Bash(git reset:*)",
      "Bash(npm install:*)",
      "Bash(pip install:*)",
      "Edit(./.github/**)",
      "Edit(./infrastructure/**)"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(curl:*)",
      "Bash(wget:*)",
      "Read(./.env*)",
      "Read(./secrets/**)",
      "Edit(./.env*)",
      "Write(./.env*)",
      "Edit(./secrets/**)",
      "Write(./secrets/**)"$EXTRA_DENY
    ]
  }$HOOKS_BLOCK
}
JSONEOF
  ok "Creado .claude/settings.json"
fi

# ─── Agentes ───────────────────────────────────────────────────────────────
title "🤖  Copiando agentes"
copy_asset "agents/planner.md"   ".claude/agents/planner.md"
copy_asset "agents/generator.md" ".claude/agents/generator.md"
if [[ "$WANT_EVALUATOR" == "yes" ]]; then
  copy_asset "agents/evaluator-light.md" ".claude/agents/evaluator.md"
fi

# ─── Commands ──────────────────────────────────────────────────────────────
title "⌨   Copiando slash commands"
copy_asset "commands/plan.md"             ".claude/commands/plan.md"
copy_asset "commands/build.md"            ".claude/commands/build.md"
copy_asset "commands/ship.md"             ".claude/commands/ship.md"
copy_asset "commands/freeze.md"           ".claude/commands/freeze.md"
copy_asset "commands/unfreeze.md"         ".claude/commands/unfreeze.md"
copy_asset "commands/configure-stack.md"  ".claude/commands/configure-stack.md"
if [[ "$WANT_EVALUATOR" == "yes" ]]; then
  copy_asset "commands/evaluate.md" ".claude/commands/evaluate.md"
fi

# ─── Hooks ─────────────────────────────────────────────────────────────────
if [[ "$ENABLE_HOOKS" == "yes" ]]; then
  title "🪝  Copiando hooks"
  copy_asset "hooks/pre-bash.sh"     ".claude/hooks/pre-bash.sh"
  copy_asset "hooks/on-stop.sh"      ".claude/hooks/on-stop.sh"
  copy_asset "hooks/freeze-guard.sh" ".claude/hooks/freeze-guard.sh"
  chmod +x .claude/hooks/*.sh
fi

# ─── Skills (siempre se copian — son referenciados por path desde agents/commands) ─
title "🧠  Copiando skills al proyecto (requeridos por agents/commands)"
for s in systematic-debugging test-driven-development verification-before-completion; do
  copy_asset "skills/$s/SKILL.md" ".claude/skills/$s/SKILL.md"
done

# ─── HARNESS.md (con fragmentos según arquitectura) ────────────────────────
title "📘  Generando HARNESS.md"
render_asset "templates/HARNESS.md.tmpl" "HARNESS.md"
if [[ "$WANT_EVALUATOR" == "yes" ]]; then
  inject_block "HARNESS.md" "EVAL_AGENT_LINE" "$(fragment eval_agent_line_B.txt)"
  inject_block "HARNESS.md" "EVAL_CMD_LINE"   "$(fragment eval_cmd_line_B.txt)"
  inject_block "HARNESS.md" "BACKLOG_EVAL"    "$(fragment backlog_B.txt)"
else
  inject_block "HARNESS.md" "EVAL_AGENT_LINE" ""
  inject_block "HARNESS.md" "EVAL_CMD_LINE"   ""
  inject_block "HARNESS.md" "BACKLOG_EVAL"    "$(fragment backlog_A.txt)"
fi

# ─── Git init ──────────────────────────────────────────────────────────────
if [[ ! -d ".git" ]]; then
  if ask_yn "¿Inicializar repo git?" "y"; then
    git init -q && git add . && git commit -q -m "chore: bootstrap harness (bundle $BUNDLE_VERSION)

Architecture: $ARCH
Target model: Opus 4.5+"
    ok "Repo git inicializado con commit inicial"
  fi
else
  warn "Repo git ya existe — se omite init"
fi

# ─── Resumen ───────────────────────────────────────────────────────────────
title "✨  Listo"
echo
echo "  ${BOLD}Bundle:${RESET} $BUNDLE_VERSION · ${BOLD}Arquitectura:${RESET} $ARCH"
echo "  ${BOLD}Próximos pasos:${RESET}"
echo "    1. ${BLUE}cd $TARGET_ABS${RESET}"
echo "    2. Editar CLAUDE.md (completar <COMPLETAR>)"
echo "    3. ${BLUE}cp .env.example .env${RESET}"
echo "    4. ${BLUE}claude${RESET}"
echo "    5. Probar: ${BLUE}/plan \"una app de notas\"${RESET}"
echo
echo "  ${BOLD}Documentación:${RESET} AGENT_HARNESS_GUIDE_V2.md"
echo
