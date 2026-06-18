# harness-bundle

Scaffolder en shell para bootstrapear un harness **Planner · Generator · Evaluator** sobre Claude Code en cualquier proyecto nuevo. Inspirado en [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Anthropic Labs, mar-2026) y optimizado para **Opus 4.5 o superior**.

> Este repo es la **herramienta** que instala el harness. No es un proyecto-objetivo: corrés `init-harness.sh` desde acá apuntando a otro directorio, y el harness queda materializado allá.

---

## Qué te entrega el harness generado

Por cada proyecto que bootstrapeás:

```
mi-proyecto/
├── CLAUDE.md                 # contrato del proyecto (prompt persistente)
├── .mcp.json                 # MCPs (vacío al inicio; /config-stack lo puebla)
├── .claude/
│   ├── agents/               # planner.md, generator.md, evaluator-light.md
│   ├── commands/             # /plan, /config-stack, /build, /evaluate, /ship
│   ├── skills/               # TDD, systematic-debugging, verification (universales)
│   ├── hooks/                # on-stop, pre-bash, user-prompt-validator, ...
│   └── settings.json         # permissions + hooks
├── docs/                     # architecture.md + decisions/
└── memory/                   # specs/, backlog.md, decisions.md, evaluations/, sessions/
```

El **flujo end-to-end** dentro de Claude Code:

```
/plan → /config-stack → /build → (/evaluate) → /ship
                          ↑          ↓
                          └──── memory/backlog.md
```

- **`/plan <objetivo>`** — el `planner` expande tu prompt a un spec rico en `memory/specs/`, decide stack alto nivel, confirma deploy target.
- **`/config-stack`** — reta y confirma el stack (tabla comparativa), copia skill-packs aplicables, declara MCPs en `.mcp.json` según deploy+stack+git.
- **`/build`** — el `generator` implementa el spec feature por feature, resuelve items de `memory/backlog.md`.
- **`/evaluate`** — (opcional, Nivel B) el `evaluator-light` revisa código y tests sin browser, persiste findings P0/P1/P2 al backlog.
- **`/ship`** — verification gate → lint → tests → secret-scan → commit → deploy (cloudflare/railway/vercel/none).

## Niveles de arquitectura

| Nivel | Agentes | Cuándo |
|---|---|---|
| **A** (MVP) | Planner + Generator | Trabajo diario, tareas dentro de lo que Opus 4.5+ hace solo. |
| **B** | + Evaluator ligero (sin browser) | Apps con lógica de negocio, edge cases, "se ve bien pero no sé si funciona". |
| **C** | + Evaluator completo con Playwright | Apps con UI, entregables a cliente. **Pendiente — ver backlog en `CLAUDE.md`.** |

Regla de oro: vive en A todo lo que puedas; sube de nivel solo cuando una tarea real te muestre que el actual no basta.

---

## Quick start

### 1. Hacer ejecutables

```bash
cd ~/CodeLab/harness-bundle
chmod +x *.sh
```

### 2. Por cada proyecto nuevo

```bash
./check-skills.sh                                   # ANTES: auditar ~/.claude/ (plugins/skills globales)
./init-harness.sh ~/proyectos/mi-app-nueva          # crear scaffold (interactivo)
./check-skills.sh                                   # DESPUÉS: confirmar que nada se "encendió"
cd ~/proyectos/mi-app-nueva
claude                                              # abrir Claude Code
```

> Para exponer `check-skills` e `init-harness` como comandos globales, ver `USER_GUIDE.md`.

Dentro de Claude Code:

```
/plan "una app de notas con tags y búsqueda"
/config-stack
/build
```

Eso es todo. El planner decide el stack — vos no lo pre-elegís.

### Modo no-interactivo

```bash
HARNESS_PROJECT_NAME=mi-app \
HARNESS_MISSION="Notas con tags" \
HARNESS_ARCH=B \
HARNESS_DEPLOY=railway \
init-harness --non-interactive ~/proyectos/mi-app
```

Variables soportadas: `HARNESS_PROJECT_NAME`, `HARNESS_MISSION`, `HARNESS_PROJECT_TYPE` (`Estándar`|`Regulado`), `HARNESS_ARCH` (`A`|`B`), `HARNESS_GIT` (`yes`|`no`), `HARNESS_DEPLOY` (`none`|`cloudflare`|`railway`|`vercel`), `HARNESS_HOOK_*`.

---

## Componentes del bundle

| Script | Para qué |
|---|---|
| `check-skills.sh` | Audita `~/.claude/` cruzando contra §12 del strategy. Read-only por default; `--suggest` imprime comandos, `--interactive` los ejecuta con confirmación + backup. |
| `init-harness.sh` | Bootstrap del proyecto. Idempotente: re-correrlo no destruye customizaciones. |
| `assets/` | Contenido estático: agents, commands, hooks, skills, skill-packs, templates. La shell ensambla; los assets son el contenido. |

### Stack del bundle

- **Bash 3.2** (default macOS, `/bin/bash`). Sin features de Bash 4+.
- POSIX userland: `sed`, `awk` (BSD), `grep`, `mkdir`, `cp`, `cat`, `head`, `mktemp`, `shasum -a 256`.
- Sin runtime adicional (ni Node, ni Python, ni `jq`).

---

## Estructura del repo

```
harness-bundle/
├── README.md              # este archivo
├── CLAUDE.md              # reglas para trabajar SOBRE el bundle + backlog
├── USER_GUIDE.md          # guía paso a paso end-to-end
├── harness_strategy.md    # FUENTE DE VERDAD (estrategia v2.2 de Anthropic)
├── MANIFEST.md            # inventario + checksums de assets
├── VERSION                # versión del bundle (hoy: 1h)
├── init-harness.sh        # LÓGICA del scaffolder
├── check-skills.sh        # auditoría de ~/.claude/
├── tests/                 # E2E (smoke estructural + claude headless)
└── assets/
    ├── agents/            # planner, generator, evaluator-light
    ├── commands/          # plan, config-stack, build, evaluate, ship
    ├── hooks/             # on-stop, pre-bash, user-prompt-validator, ...
    ├── skills/            # universales: TDD, systematic-debugging, verification
    ├── skill-packs/       # librería por stack (vacía a propósito al inicio)
    └── templates/         # CLAUDE.md.tmpl, HARNESS.md.tmpl, fragments/
```

---

## Cómo trabajar en este repo

Cambios siguen la regla de **decoupling shell/contenido**:

| Cambio | Dónde |
|---|---|
| Texto de un agente, command, fragment | `assets/...` + actualizar checksum en `MANIFEST.md` (`shasum -a 256 <archivo> \| cut -c1-12`) |
| Flujo, pregunta nueva, fix de bug | `init-harness.sh` + bump de `VERSION` si cambia la interfaz observable |
| Estrategia conceptual | `harness_strategy.md` primero, después la shell |

Validación local obligatoria antes de declarar terminado:

```bash
./init-harness.sh /tmp/harness-test-$(date +%s)     # smoke
./tests/e2e-scaffold.sh                              # E2E estructural (no requiere API key)
./tests/e2e-claude.sh                                # E2E con claude headless (requiere ANTHROPIC_API_KEY)
```

Idempotencia: correr `init-harness.sh` 2 veces contra el mismo dir debe omitir lo existente sin romper.

Convenciones no negociables: conventional commits, `set -euo pipefail` permanece, mensajes en español, MANIFEST siempre sincronizado.

---

## Referencias

- **`harness_strategy.md`** — fuente de verdad: arquitectura, filosofía, plan de implementación, limpieza de configuración (§12), templates (§15).
- **`USER_GUIDE.md`** — paso a paso para usuarios finales del bundle.
- **`CLAUDE.md`** — reglas de trabajo sobre este repo + backlog priorizado (P0-P3).
- **`MANIFEST.md`** — inventario actualizado de assets con checksums.

## Estado actual

- **Versión:** v1h (ver `VERSION`)
- **Niveles soportados:** A (MVP) y B (evaluator ligero sin browser)
- **Pendiente:** Nivel C (evaluator + Playwright) y limpieza de drift de docs — ver backlog priorizado en `CLAUDE.md`.
