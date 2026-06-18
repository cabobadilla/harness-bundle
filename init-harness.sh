#!/usr/bin/env bash
#
# init-harness.sh — Bootstrap an Agent Harness for Claude Code (Opus 4.5+)
# Bundle edition v1g — DESACOPLADO: la lógica vive aquí, el contenido en assets/
#
# Architecture: Planner · Generator · Evaluator(ligero)
#   Nivel A (MVP):  Planner + Generator
#   Nivel B:        + Evaluator ligero (sin browser)
#   Nivel C:        + Evaluator Playwright — EN BACKLOG, no implementado
#
# Usage:
#   ./init-harness.sh                      # interactivo, pregunta el directorio
#   ./init-harness.sh ./mi-proyecto        # interactivo en el directorio dado
#   ./init-harness.sh --non-interactive ./mi-proyecto
#       # No-interactivo. Lee defaults de env vars:
#       #   HARNESS_PROJECT_NAME, HARNESS_MISSION, HARNESS_PROJECT_TYPE
#       #   HARNESS_ARCH (A|B), HARNESS_GIT (yes|no), HARNESS_DEPLOY (none|cloudflare|railway|vercel|manual)
#       #   HARNESS_MCP_GITHUB (yes|no), HARNESS_MCP_POSTGRES (yes|no)
#       #   HARNESS_HOOK_ON_STOP / PRE_BASH / USER_PROMPT_VALIDATOR / POST_EDIT_FORMAT / SESSION_START / SUBAGENT_STOP
#
# Requiere: la carpeta assets/ junto a este script.
# Idempotente: omite archivos que ya existen.
#

set -euo pipefail

# ─── Flags ─────────────────────────────────────────────────────────────────
NON_INTERACTIVE="no"
TARGET_ARG=""
for arg in "$@"; do
  case "$arg" in
    --non-interactive|-y) NON_INTERACTIVE="yes" ;;
    -h|--help)
      sed -n '2,25p' "$0"; exit 0 ;;
    *) TARGET_ARG="$arg" ;;
  esac
done

# ─── Localización del bundle (resolviendo symlinks) ────────────────────────
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
  if [[ "$NON_INTERACTIVE" == "yes" ]]; then echo "$default"; return; fi
  if [[ -n "$default" ]]; then
    read -r -p "  $prompt [$default]: " var; echo "${var:-$default}"
  else
    read -r -p "  $prompt: " var; echo "$var"
  fi
}

ask_choice() {
  local prompt="$1"; shift
  local options=("$@"); local count=${#options[@]}
  if [[ "$NON_INTERACTIVE" == "yes" ]]; then echo "${options[0]}"; return; fi
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
  if [[ "$NON_INTERACTIVE" == "yes" ]]; then [[ "$default" == "y" ]]; return; fi
  local hint="[y/N]"; [[ "$default" == "y" ]] && hint="[Y/n]"
  read -r -p "  $prompt $hint: " ans; ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ─── Helpers de assets ─────────────────────────────────────────────────────
render_asset() {
  local src="$ASSETS/$1"; local dst="$2"
  if [[ ! -f "$src" ]]; then err "Asset no encontrado: $1"; return 1; fi
  if [[ -e "$dst" ]]; then warn "$dst ya existe — se omite"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME:-}|g" \
      -e "s|__PROJECT_NAME__|${PROJECT_NAME:-}|g" \
      -e "s|{{MISSION}}|${MISSION:-}|g" \
      -e "s|{{ARCH}}|${ARCH:-}|g" \
      -e "s|{{DEPLOY_TARGET}}|${DEPLOY_TARGET:-none}|g" \
      -e "s|{{DATE}}|$(date +%Y-%m-%d)|g" \
      -e "s|{{BUNDLE_VERSION}}|${BUNDLE_VERSION}|g" \
      "$src" > "$dst"
  ok "Creado $dst"
}

copy_asset() {
  local src="$ASSETS/$1"; local dst="$2"
  if [[ ! -e "$src" ]]; then err "Asset no encontrado: $1"; return 1; fi
  if [[ -e "$dst" ]]; then warn "$dst ya existe — se omite"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  ok "Creado $dst"
}

fragment() {
  cat "$ASSETS/templates/fragments/$1" 2>/dev/null || echo ""
}

inject_block() {
  local file="$1"; local key="$2"; local content="$3"
  local tmp frag
  tmp=$(mktemp)
  frag=$(mktemp)
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

# Helper para flags yes/no via env var con default
env_yn() {
  local var="$1"; local default="$2"
  local val="${!var:-$default}"
  if [[ "$val" == "yes" || "$val" == "y" || "$val" == "1" ]]; then echo "yes"; else echo "no"; fi
}

# ─── Directorio destino ────────────────────────────────────────────────────
title "🛠  Agent Harness Bootstrap — bundle $BUNDLE_VERSION (Opus 4.5+)"
say "Arquitectura: Planner · Generator · Evaluator"
[[ "$NON_INTERACTIVE" == "yes" ]] && say "Modo no-interactivo (defaults via HARNESS_* env vars)"
echo

title "📁  Directorio del proyecto"
if [[ -n "$TARGET_ARG" ]]; then
  TARGET="$TARGET_ARG"
  say "Usando el directorio pasado como argumento: $TARGET"
else
  echo "  Este es el directorio DONDE SE CREARÁ el harness." >&2
  TARGET=$(ask "Ruta del proyecto (Enter = directorio actual)" ".")
fi
[[ ! -d "$TARGET" ]] && { mkdir -p "$TARGET"; ok "Creado directorio $TARGET"; }
cd "$TARGET"; TARGET_ABS=$(pwd)
say "Harness se creará en: $TARGET_ABS"

# ─── Información del proyecto ──────────────────────────────────────────────
title "📝  Información del proyecto"
if [[ "$NON_INTERACTIVE" != "yes" ]]; then
  echo "  El planner usa la MISIÓN como contexto inicial para generar el spec." >&2
  echo "  Sé concreto: qué problema resolvés, para quién, qué hace único al proyecto." >&2
  echo "  El stack NO se pregunta acá — lo define el planner en /plan y se reta con /config-stack." >&2
fi
PROJECT_NAME=$(ask "Nombre del proyecto" "${HARNESS_PROJECT_NAME:-$(basename "$TARGET_ABS")}")
MISSION=$(ask "Misión (1-2 frases — qué hace, para quién)" "${HARNESS_MISSION:-<COMPLETAR>}")

PROJECT_TYPE=$(ask_choice "Tipo de proyecto:" \
  "${HARNESS_PROJECT_TYPE:-Personal}" \
  "Cliente enterprise (estándar)" \
  "Cliente regulado (banca/salud/gov)")

# ─── Arquitectura ──────────────────────────────────────────────────────────
title "🤖  Arquitectura de agentes"
if [[ "$NON_INTERACTIVE" != "yes" ]]; then
  echo "  A) MVP — Planner + Generator (lo más simple)" >&2
  echo "  B) + Evaluator LIGERO — revisa código/output, sin browser (recomendado)" >&2
  echo "  (Nivel C — Evaluator completo con Playwright — en el backlog, aún no implementado)" >&2
fi
ARCH_DEFAULT="${HARNESS_ARCH:-B}"
case "$ARCH_DEFAULT" in
  A|a) ARCH_DEFAULT_LBL="A - MVP (Planner + Generator)" ;;
  *)   ARCH_DEFAULT_LBL="B - Evaluator ligero (sin Playwright)" ;;
esac
ARCH=$(ask_choice "¿Qué arquitectura?:" \
  "$ARCH_DEFAULT_LBL" \
  "A - MVP (Planner + Generator)" \
  "B - Evaluator ligero (sin Playwright)")
WANT_EVALUATOR="no"; case "$ARCH" in B*) WANT_EVALUATOR="yes" ;; esac

# ─── Git ───────────────────────────────────────────────────────────────────
title "📦  Control de versiones"
echo "  Si elegís NO inicializar git, los permisos Bash(git *) se omiten del settings.json." >&2
WANT_GIT=$(env_yn HARNESS_GIT "no")
if [[ "$NON_INTERACTIVE" != "yes" ]]; then
  if ask_yn "¿Inicializar repo git?" "n"; then WANT_GIT="yes"; else WANT_GIT="no"; fi
fi

# ─── Deploy target ─────────────────────────────────────────────────────────
title "🚀  Deployment target"
if [[ "$NON_INTERACTIVE" != "yes" ]]; then
  echo "  Define dónde se va a desplegar el proyecto. Habilita MCP correspondiente." >&2
  echo "  • none       — no deploy (decidir después)" >&2
  echo "  • cloudflare — Workers/Pages (MCP local oficial)" >&2
  echo "  • railway    — Railway (MCP remoto https://mcp.railway.com)" >&2
  echo "  • vercel     — Vercel (MCP remoto https://mcp.vercel.com)" >&2
  echo "  • manual     — checklist de deploy manual, sin MCP" >&2
fi
DEPLOY_DEFAULT="${HARNESS_DEPLOY:-none}"
DEPLOY_TARGET=$(ask_choice "Deploy target:" \
  "$DEPLOY_DEFAULT" \
  "none" \
  "cloudflare" \
  "railway" \
  "vercel" \
  "manual")

# ─── MCPs ──────────────────────────────────────────────────────────────────
title "🔌  MCPs (además del de deploy)"
MCP_GITHUB=$(env_yn HARNESS_MCP_GITHUB "no")
MCP_POSTGRES=$(env_yn HARNESS_MCP_POSTGRES "no")
if [[ "$NON_INTERACTIVE" != "yes" ]]; then
  ask_yn "¿Habilitar MCP github?" "n" && MCP_GITHUB="yes" || MCP_GITHUB="no"
  ask_yn "¿Habilitar MCP postgres?" "n" && MCP_POSTGRES="yes" || MCP_POSTGRES="no"
fi

# ─── Hooks (selector por hook) ─────────────────────────────────────────────
title "🛡  Hooks (selecciona cuáles instalar)"
if [[ "$NON_INTERACTIVE" != "yes" ]]; then
  echo "  Eventos disponibles. Defaults marcados con [Y/n]." >&2
fi
HOOK_ON_STOP=$(env_yn HARNESS_HOOK_ON_STOP "yes")
HOOK_PRE_BASH=$(env_yn HARNESS_HOOK_PRE_BASH "yes")
HOOK_USER_PROMPT_VALIDATOR=$(env_yn HARNESS_HOOK_USER_PROMPT_VALIDATOR "yes")
HOOK_POST_EDIT_FORMAT=$(env_yn HARNESS_HOOK_POST_EDIT_FORMAT "no")
HOOK_SESSION_START=$(env_yn HARNESS_HOOK_SESSION_START "no")
HOOK_SUBAGENT_STOP=$(env_yn HARNESS_HOOK_SUBAGENT_STOP "no")

if [[ "$NON_INTERACTIVE" != "yes" ]]; then
  ask_yn "on-stop (persiste resumen de sesión)" "y" && HOOK_ON_STOP="yes" || HOOK_ON_STOP="no"
  ask_yn "pre-bash (bloquea comandos peligrosos)" "y" && HOOK_PRE_BASH="yes" || HOOK_PRE_BASH="no"
  ask_yn "user-prompt-validator (filtra secretos en prompts)" "y" && HOOK_USER_PROMPT_VALIDATOR="yes" || HOOK_USER_PROMPT_VALIDATOR="no"
  ask_yn "post-edit-format (auto-formato tras Edit/Write)" "n" && HOOK_POST_EDIT_FORMAT="yes" || HOOK_POST_EDIT_FORMAT="no"
  ask_yn "session-start (resumen al abrir sesión)" "n" && HOOK_SESSION_START="yes" || HOOK_SESSION_START="no"
  ask_yn "subagent-stop (log de subagentes)" "n" && HOOK_SUBAGENT_STOP="yes" || HOOK_SUBAGENT_STOP="no"
fi

ANY_HOOKS="no"
for v in HOOK_ON_STOP HOOK_PRE_BASH HOOK_USER_PROMPT_VALIDATOR HOOK_POST_EDIT_FORMAT HOOK_SESSION_START HOOK_SUBAGENT_STOP; do
  [[ "${!v}" == "yes" ]] && ANY_HOOKS="yes"
done

# ─── Confirmación ──────────────────────────────────────────────────────────
title "📂  Confirmación"
echo "  Crear en:           $TARGET_ABS"
echo "  Proyecto:           $PROJECT_NAME"
echo "  Tipo:               $PROJECT_TYPE"
echo "  Arquitectura:       $ARCH"
echo "  Evaluator:          $([ "$WANT_EVALUATOR" == "yes" ] && echo "ligero" || echo "no")"
echo "  Git init:           $WANT_GIT"
echo "  Deploy target:      $DEPLOY_TARGET"
echo "  MCP github:         $MCP_GITHUB"
echo "  MCP postgres:       $MCP_POSTGRES"
echo "  Hooks:"
echo "    on-stop:                  $HOOK_ON_STOP"
echo "    pre-bash:                 $HOOK_PRE_BASH"
echo "    user-prompt-validator:    $HOOK_USER_PROMPT_VALIDATOR"
echo "    post-edit-format:         $HOOK_POST_EDIT_FORMAT"
echo "    session-start:            $HOOK_SESSION_START"
echo "    subagent-stop:            $HOOK_SUBAGENT_STOP"
echo "  Bundle:             $BUNDLE_VERSION"
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
render_asset "templates/backlog.md.tmpl"         "memory/backlog.md"

# ─── CLAUDE.md ─────────────────────────────────────────────────────────────
render_asset "templates/CLAUDE.md.tmpl" "CLAUDE.md"
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

case "$DEPLOY_TARGET" in
  cloudflare)
    MCP_ENTRIES+=('"cloudflare-bindings": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://bindings.mcp.cloudflare.com/sse"]
    }')
    ;;
  railway)
    MCP_ENTRIES+=('"railway": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.railway.com"]
    }')
    ;;
  vercel)
    MCP_ENTRIES+=('"vercel": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.vercel.com"]
    }')
    ;;
esac

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

# Bloque condicional de permisos git
GIT_PERMS=""
if [[ "$WANT_GIT" == "yes" ]]; then
  GIT_PERMS='
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
      "Bash(git init:*)",'
fi

# Ask permissions condicionales para git
GIT_ASK=""
if [[ "$WANT_GIT" == "yes" ]]; then
  GIT_ASK='
      "Bash(git push:*)",
      "Bash(git reset:*)",'
fi

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

# Construir bloque de hooks dinámicamente
HOOKS_BLOCK=""
if [[ "$ANY_HOOKS" == "yes" ]]; then
  PRE_TOOL_USE_HOOKS=""
  if [[ "$HOOK_PRE_BASH" == "yes" ]]; then
    PRE_TOOL_USE_HOOKS+='
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": ".claude/hooks/pre-bash.sh" } ] }'
  fi

  POST_TOOL_USE_HOOKS=""
  if [[ "$HOOK_POST_EDIT_FORMAT" == "yes" ]]; then
    POST_TOOL_USE_HOOKS+='
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": ".claude/hooks/post-edit-format.sh" } ] }'
  fi

  STOP_HOOKS=""
  if [[ "$HOOK_ON_STOP" == "yes" ]]; then
    STOP_HOOKS+='
      { "hooks": [ { "type": "command", "command": ".claude/hooks/on-stop.sh" } ] }'
  fi

  USER_PROMPT_HOOKS=""
  if [[ "$HOOK_USER_PROMPT_VALIDATOR" == "yes" ]]; then
    USER_PROMPT_HOOKS+='
      { "hooks": [ { "type": "command", "command": ".claude/hooks/user-prompt-validator.sh" } ] }'
  fi

  SESSION_START_HOOKS=""
  if [[ "$HOOK_SESSION_START" == "yes" ]]; then
    SESSION_START_HOOKS+='
      { "hooks": [ { "type": "command", "command": ".claude/hooks/session-start.sh" } ] }'
  fi

  SUBAGENT_STOP_HOOKS=""
  if [[ "$HOOK_SUBAGENT_STOP" == "yes" ]]; then
    SUBAGENT_STOP_HOOKS+='
      { "hooks": [ { "type": "command", "command": ".claude/hooks/subagent-stop.sh" } ] }'
  fi

  HOOKS_BLOCK=',
  "hooks": {'
  FIRST=1
  add_block() {
    local name="$1"; local content="$2"
    [[ -z "$content" ]] && return
    [[ $FIRST -eq 0 ]] && HOOKS_BLOCK+=","
    HOOKS_BLOCK+="
    \"$name\": [$content
    ]"
    FIRST=0
  }
  add_block "PreToolUse"      "$PRE_TOOL_USE_HOOKS"
  add_block "PostToolUse"     "$POST_TOOL_USE_HOOKS"
  add_block "Stop"            "$STOP_HOOKS"
  add_block "UserPromptSubmit" "$USER_PROMPT_HOOKS"
  add_block "SessionStart"    "$SESSION_START_HOOKS"
  add_block "SubagentStop"    "$SUBAGENT_STOP_HOOKS"
  HOOKS_BLOCK+='
  }'
fi

if [[ -e .claude/settings.json ]]; then
  warn ".claude/settings.json ya existe — se omite"
else
cat > .claude/settings.json <<JSONEOF
{
  "permissions": {
    "allow": [$GIT_PERMS
      "Bash(npm test:*)",
      "Bash(npm run:*)",
      "Bash(npm ci:*)",
      "Bash(pytest:*)",
      "Bash(python -m venv:*)",
      "Bash(source .venv/bin/activate:*)",
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
    "ask": [$GIT_ASK
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
copy_asset "commands/config-stack.md"     ".claude/commands/config-stack.md"
copy_asset "commands/build.md"            ".claude/commands/build.md"
copy_asset "commands/ship.md"             ".claude/commands/ship.md"
if [[ "$WANT_EVALUATOR" == "yes" ]]; then
  copy_asset "commands/evaluate.md" ".claude/commands/evaluate.md"
fi

# ─── Hooks ─────────────────────────────────────────────────────────────────
if [[ "$ANY_HOOKS" == "yes" ]]; then
  title "🪝  Copiando hooks seleccionados"
  [[ "$HOOK_ON_STOP" == "yes" ]]               && copy_asset "hooks/on-stop.sh"               ".claude/hooks/on-stop.sh"
  [[ "$HOOK_PRE_BASH" == "yes" ]]              && copy_asset "hooks/pre-bash.sh"              ".claude/hooks/pre-bash.sh"
  [[ "$HOOK_USER_PROMPT_VALIDATOR" == "yes" ]] && copy_asset "hooks/user-prompt-validator.sh" ".claude/hooks/user-prompt-validator.sh"
  [[ "$HOOK_POST_EDIT_FORMAT" == "yes" ]]      && copy_asset "hooks/post-edit-format.sh"      ".claude/hooks/post-edit-format.sh"
  [[ "$HOOK_SESSION_START" == "yes" ]]         && copy_asset "hooks/session-start.sh"         ".claude/hooks/session-start.sh"
  [[ "$HOOK_SUBAGENT_STOP" == "yes" ]]         && copy_asset "hooks/subagent-stop.sh"         ".claude/hooks/subagent-stop.sh"
  chmod +x .claude/hooks/*.sh 2>/dev/null || true
fi

# ─── Skills ────────────────────────────────────────────────────────────────
title "🧠  Copiando skills universales"
for s in systematic-debugging test-driven-development verification-before-completion; do
  copy_asset "skills/$s/SKILL.md" ".claude/skills/$s/SKILL.md"
done

# ─── HARNESS.md ────────────────────────────────────────────────────────────
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
if [[ "$WANT_GIT" == "yes" ]]; then
  if [[ ! -d ".git" ]]; then
    git init -q && git add . && git commit -q -m "chore: bootstrap harness (bundle $BUNDLE_VERSION)

Architecture: $ARCH
Deploy target: $DEPLOY_TARGET
Target model: Opus 4.5+"
    ok "Repo git inicializado con commit inicial"
  else
    warn "Repo git ya existe — se omite init"
  fi
else
  say "Git no inicializado (permisos Bash(git *) omitidos en settings.json)"
fi

# ─── Resumen ───────────────────────────────────────────────────────────────
title "✨  Listo"
echo
echo "  ${BOLD}Bundle:${RESET} $BUNDLE_VERSION · ${BOLD}Arquitectura:${RESET} $ARCH · ${BOLD}Deploy:${RESET} $DEPLOY_TARGET"
echo "  ${BOLD}Próximos pasos:${RESET}"
echo "    1. ${BLUE}cd $TARGET_ABS${RESET}"
echo "    2. Editar CLAUDE.md (completar <COMPLETAR>)"
echo "    3. ${BLUE}cp .env.example .env${RESET}"
echo "    4. ${BLUE}claude${RESET}"
echo "    5. Probar: ${BLUE}/plan \"una app de notas\"${RESET}"
echo "    6. ${BLUE}/config-stack${RESET} → ${BLUE}/build${RESET} → (${BLUE}/evaluate${RESET}) → ${BLUE}/ship${RESET}"
echo
