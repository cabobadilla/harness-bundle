# Proyecto: harness-bundle

## Misión
Un scaffolder en shell que bootstrapea un harness Planner · Generator · Evaluator para Claude Code en cualquier proyecto nuevo, siguiendo la guía de Harness Engineering de Anthropic. **Este repo NO es un proyecto-objetivo del harness — es la HERRAMIENTA que lo instala.**

## Modelo objetivo del harness que generamos
Claude Code corriendo con **Opus 4.x (4.5 o superior)**. Sin context resets, sin sprints obligatorios. La salida del scaffolder asume ese target.

## Tech stack (este repo)
- **Bash 3.2** (macOS por default — `/bin/bash`). NO usar features de Bash 4+.
- **POSIX userland**: `sed`, `awk` (BSD), `grep`, `mkdir`, `cp`, `cat`, `tr`, `head`, `mktemp`, `sha256sum` (o `shasum -a 256`).
- **Sin runtime adicional**: ni Node, ni Python, ni jq. Si algo no se puede sin jq/python, primero discutirlo.
- Compatible con macOS (BSD awk/sed) y Linux (GNU). El runtime real del usuario es macOS — todo cambio se valida ahí primero.

## Arquitectura
```
harness-bundle/
├── init-harness.sh       # LÓGICA: flujo, preguntas, ensamblaje
├── VERSION               # versión del bundle (ej: 1d)
├── MANIFEST.md           # inventario + checksums de assets
├── harness_strategy.md   # FUENTE DE VERDAD (Anthropic harness strategy v2)
└── assets/               # CONTENIDO estático, editable sin tocar la shell
    ├── agents/           # prompts: planner.md, generator.md, evaluator-light.md
    ├── commands/         # slash commands: plan/build/ship/freeze/unfreeze/evaluate
    ├── hooks/            # pre-bash.sh, on-stop.sh, freeze-guard.sh
    ├── skills/           # systematic-debugging, TDD, verification (opcionales)
    ├── scaffolds/        # scaffold Flask (opcional al iniciar)
    └── templates/        # CLAUDE.md.tmpl, HARNESS.md.tmpl, + fragments/
```

Decoupling regla: la shell ensambla; los assets son contenido. Si un cambio toca solo texto, va a `assets/`. Si toca flujo, condicionales o ensamblaje, va a `init-harness.sh`.

## Operaciones base (cómo trabajar aquí)
1. **Cambio en contenido** (texto de un agente, un command, un fragmento) → editar bajo `assets/` y actualizar el checksum en `MANIFEST.md` (`shasum -a 256 <archivo> | cut -c1-12`).
2. **Cambio en flujo** (nueva pregunta, nuevo nivel, fix de bug) → editar `init-harness.sh`. Subir `VERSION` cuando cambia la interfaz observable.
3. **Cambio en estrategia** (qué hace el harness conceptualmente) → editar `harness_strategy.md` primero, después la shell para reflejarlo.
4. **Validación local obligatoria**: correr el script contra un directorio temporal (`/tmp/harness-test-XXXX`) antes de declarar terminado. Idempotencia: correr 2x debe omitir lo existente sin romper.
5. **Compatibilidad shell**: probar con `bash --version` = 3.2 (default macOS). Nada de `declare -A`, `mapfile`, `[[ -v ]]`, `<<<` con expansiones complejas.

## Skills que aplican al trabajar en este repo
- **`test-driven-development`** — para cambios no triviales en la shell (escribe un caso de prueba reproducible antes de tocar la lógica).
- **`systematic-debugging`** — cuando aparezca un error como el de `awk: newline in string`. No parchear a ciegas; aislar input, reproducir mínimamente, fijar la causa raíz.
- **`verification-before-completion`** — antes de declarar "listo": correr `./init-harness.sh /tmp/x` end-to-end, validar archivos generados, validar idempotencia.
- **`simplify`** — al cerrar un cambio, revisar si introdujo abstracción innecesaria.

## Convenciones no negociables
- **Conventional commits** (`fix:`, `feat:`, `chore:`, `docs:`).
- **Idempotencia**: cualquier paso del script puede correrse 2 veces sin destruir trabajo. Si un archivo ya existe, se omite con `warn`, no se sobreescribe.
- **`set -euo pipefail` permanece**: si algo falla, falla ruidoso. Nunca silenciar con `|| true` salvo en checksums opcionales.
- **Mensajes en español** (el público objetivo lo es); comentarios técnicos en español o inglés, consistencia local.
- **No introducir plugins de comunidad** como dependencia del scaffolder (el harness que genera explícitamente los desinstala — sección 12 de `harness_strategy.md`).
- **MANIFEST.md siempre sincronizado** con el contenido real de `assets/`. Un asset sin entrada en MANIFEST es un bug.

## Lo que NO se hace acá
- No agregar features que el `harness_strategy.md` no contempla, salvo decisión explícita del usuario.
- No auto-ejecutar el harness generado durante tests del scaffolder. Esto es un instalador, no un runner.
- No depender de herramientas que el usuario podría no tener (jq, gawk, GNU sed, python). Si se necesitan, hacerlo opcional con fallback.
- No tocar `~/.claude/` desde este script automáticamente. La limpieza de skills/plugins globales se hace con un script aparte y siempre confirmando con el usuario.

## Backlog del bundle
Trabajo pendiente sobre el scaffolder mismo (no sobre proyectos que genera):

- [ ] **Fase C — Evaluator completo (Playwright)**: completar el agente de verificación completa. Hoy el bundle entrega Nivel A (planner+generator) y Nivel B (evaluator ligero, sin browser). Falta el Nivel C: agente `evaluator-full.md` que use Playwright MCP para navegar la app generada como usuario real, con los 4 criterios + thresholds duros de §10 de `harness_strategy.md`. Incluye:
  - `assets/agents/evaluator-full.md` (versión con `mcp__playwright__*` en tools)
  - Declarar `playwright` en `.mcp.json` cuando el usuario elige Nivel C
  - Nueva opción "C" en el menú de arquitectura del `init-harness.sh`
  - Fragmentos `eval_workflow_C.txt`, `backlog_C.txt`
  - Validación: bug intencional de UI en una app de prueba → el evaluator lo detecta y reporta con `file:line`
- [ ] **`check-skills.sh`** — pre-flight de skills/plugins globales antes del bootstrap (Fase 3 del plan original).

## Referencias persistentes
- `@harness_strategy.md` — fuente de verdad de la arquitectura y filosofía del harness.
- `@MANIFEST.md` — inventario actual del bundle.
- `@VERSION` — versión del bundle.
