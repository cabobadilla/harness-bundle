#!/usr/bin/env bash
#
# install-global.sh — Expone los scripts del bundle como comandos globales
#                     vía symlinks en ~/.local/bin (o el dir que elijas).
#
# Comandos que instala:
#   check-skills   → check-skills.sh   (auditor de ~/.claude/)
#   init-harness   → init-harness.sh   (scaffolder del proyecto)
#
# Estrategia:
#   • Symlinks (no copias) → un solo source of truth en el bundle.
#   • Idempotente: re-ejecutarlo no rompe nada.
#   • No-destructivo: si hay colisión en el target, aborta con mensaje claro.
#   • NO modifica tus dotfiles. Si falta PATH, te dice qué agregar.
#
# Uso:
#   ./install-global.sh                            # ambos en ~/.local/bin
#   ./install-global.sh --dest /usr/local/bin      # otro directorio
#   ./install-global.sh --only check-skills        # solo uno
#   ./install-global.sh --help
#

set -euo pipefail

# ─── Colores ───────────────────────────────────────────────────────────────
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

# ─── Args ──────────────────────────────────────────────────────────────────
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

# ─── Resolver bundle dir ───────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Tabla de instalación: "link_name|source_file"
INSTALLS=()
[[ -z "$ONLY" || "$ONLY" == "check-skills" ]] && INSTALLS+=("check-skills|check-skills.sh")
[[ -z "$ONLY" || "$ONLY" == "init-harness" ]] && INSTALLS+=("init-harness|init-harness.sh")

if [[ ${#INSTALLS[@]} -eq 0 ]]; then
  err "Nada para instalar. --only acepta: check-skills, init-harness"
  exit 2
fi

# ─── Crear dir destino si falta ────────────────────────────────────────────
if [[ ! -d "$DEST" ]]; then
  mkdir -p "$DEST"
  ok "Creado $DEST"
fi

# ─── Función: instalar un symlink (idempotente, no-destructivo) ────────────
install_one() {
  local link_name="$1" source_file="$2"
  local source="${SCRIPT_DIR}/${source_file}"
  local target="${DEST}/${link_name}"

  if [[ ! -f "$source" ]]; then
    err "No se encontró $source — ¿estás corriendo desde el bundle?"
    return 1
  fi
  [[ -x "$source" ]] || chmod +x "$source"

  if [[ -L "$target" ]]; then
    local current; current=$(readlink "$target")
    if [[ "$current" == "$source" ]]; then
      ok "$link_name → $source_file   (ya existía, OK)"
      return 0
    else
      err "$target apunta a OTRO archivo:"
      err "  actual:    $current"
      err "  esperado:  $source"
      err "Removelo si querés reemplazar: rm '$target'"
      return 1
    fi
  elif [[ -e "$target" ]]; then
    err "$target existe pero NO es un symlink. No lo sobreescribo."
    return 1
  else
    ln -s "$source" "$target"
    ok "$link_name → $source_file   (symlink creado)"
    return 0
  fi
}

# ─── Loop de instalación ───────────────────────────────────────────────────
say "Destino: $DEST"
echo
FAIL=0
for entry in "${INSTALLS[@]}"; do
  link_name="${entry%%|*}"
  source_file="${entry#*|}"
  install_one "$link_name" "$source_file" || FAIL=1
done

if [[ $FAIL -ne 0 ]]; then
  err "Una o más instalaciones fallaron — revisá los mensajes."
  exit 1
fi

# ─── Verificar PATH ────────────────────────────────────────────────────────
echo
case ":$PATH:" in
  *":$DEST:"*)
    ok "$DEST está en tu PATH."
    ;;
  *)
    warn "$DEST NO está en tu PATH."
    echo "  Agregá esta línea a tu ~/.zshrc o ~/.bashrc:"
    echo
    echo "    ${BOLD}export PATH=\"$DEST:\$PATH\"${RESET}"
    echo
    echo "  Después: ${BOLD}source ~/.zshrc${RESET} (o abrí una nueva terminal)."
    ;;
esac

# ─── Smoke tests ───────────────────────────────────────────────────────────
echo
say "Smoke tests:"
for entry in "${INSTALLS[@]}"; do
  link_name="${entry%%|*}"
  target="${DEST}/${link_name}"
  if "$target" --help >/dev/null 2>&1; then
    ok "${BOLD}$link_name${RESET} --help responde."
  else
    # init-harness no tiene --help (es interactivo). Validamos solo que sea ejecutable.
    if [[ -x "$target" ]]; then
      ok "${BOLD}$link_name${RESET} es ejecutable (sin flag --help)."
    else
      err "$link_name no es ejecutable: $target"
      FAIL=1
    fi
  fi
done

echo
if [[ $FAIL -eq 0 ]]; then
  ok "Instalación global completa."
  echo "  Probá: ${BOLD}check-skills${RESET}  y  ${BOLD}init-harness /ruta/proyecto-nuevo${RESET}"
else
  err "Instalación completa con advertencias."
  exit 1
fi
