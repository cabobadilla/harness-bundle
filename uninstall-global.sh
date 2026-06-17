#!/usr/bin/env bash
#
# uninstall-global.sh — Quita los symlinks globales del bundle
#
# Solo borra si:
#   • $target es un symlink, Y
#   • apunta al archivo correspondiente de ESTE bundle.
# Si es otro archivo / otro symlink, aborta y te dice qué hay.
#
# Uso:
#   ./uninstall-global.sh                       # quita ambos
#   ./uninstall-global.sh --dest /usr/local/bin
#   ./uninstall-global.sh --only check-skills   # solo uno
#

set -euo pipefail

if [[ -t 1 ]]; then
  BOLD=$(tput bold); RESET=$(tput sgr0)
  GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); BLUE=$(tput setaf 4); RED=$(tput setaf 1)
else
  BOLD=""; RESET=""; GREEN=""; YELLOW=""; BLUE=""; RED=""
fi
say()  { echo -e "${BLUE}▸${RESET} $*"; }
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
err()  { echo -e "${RED}✗${RESET} $*" >&2; }

DEST="${HOME}/.local/bin"
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest) DEST="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *) err "Argumento desconocido: $1 (usa --help)"; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REMOVALS=()
[[ -z "$ONLY" || "$ONLY" == "check-skills" ]] && REMOVALS+=("check-skills|check-skills.sh")
[[ -z "$ONLY" || "$ONLY" == "init-harness" ]] && REMOVALS+=("init-harness|init-harness.sh")

say "Destino: $DEST"
echo

uninstall_one() {
  local link_name="$1" source_file="$2"
  local source="${SCRIPT_DIR}/${source_file}"
  local target="${DEST}/${link_name}"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    ok "$link_name → no existe (nada que hacer)."
    return 0
  fi
  if [[ ! -L "$target" ]]; then
    err "$target existe pero NO es un symlink — no lo toco."
    return 1
  fi
  local current; current=$(readlink "$target")
  if [[ "$current" != "$source" ]]; then
    err "$target apunta a OTRO archivo:"
    err "  actual:           $current"
    err "  de este bundle:   $source"
    err "No lo toco (puede ser de otra instalación)."
    return 1
  fi
  rm "$target"
  ok "$link_name → eliminado"
  return 0
}

FAIL=0
for entry in "${REMOVALS[@]}"; do
  link_name="${entry%%|*}"
  source_file="${entry#*|}"
  uninstall_one "$link_name" "$source_file" || FAIL=1
done

echo
if [[ $FAIL -eq 0 ]]; then
  ok "Desinstalación global completa."
  warn "Los scripts del bundle siguen en $SCRIPT_DIR — esto solo quitó el acceso global."
else
  err "Algunos symlinks no se pudieron remover — revisá manualmente."
  exit 1
fi
