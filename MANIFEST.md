# MANIFEST — Harness Bundle

**Bundle version:** `1g`
**Generado:** 2026-06-17

La shell (`init-harness.sh`) contiene la LÓGICA. Los `assets/` contienen el CONTENIDO estático.
Editar un asset no requiere tocar la shell. Tras editar, actualiza su checksum con:
`shasum -a 256 <archivo> | cut -c1-12`

## Cambios v1f → v1g

### Commands
- **Eliminados** `freeze.md` y `unfreeze.md` (junto al hook `freeze-guard.sh`).
- **Renombrado** `configure-stack.md` → `config-stack.md`, rediseñado como **challenger del stack**: presenta tabla comparativa (opción/complejidad/pros/contras/encaje con deploy), reta al usuario antes de cementar, persiste decisión en `CLAUDE.md` + `memory/decisions.md`, recién después copia skill-packs.
- **`/build`** ahora declara explícitamente que lee `memory/spec/<slug>.md` Y `memory/backlog.md` (los ítems abiertos del backlog son input además del spec).
- **`/evaluate`** documenta el loop completo: evaluator escribe findings P0/P1/P2 a `memory/backlog.md` (append), `/build` los resuelve en la siguiente iteración.
- **`/ship`** rediseñado con 7 pasos: verification gate → lint → tests → secret-scan → diff → commit → **deploy según `DEPLOY_TARGET`** (wrangler/railway/vercel/manual/none) → push opcional.

### Hooks
- **Eliminado:** `freeze-guard.sh` (sin `/freeze`).
- **Nuevo selector por hook** en `init-harness.sh` (reemplaza el toggle global). Defaults:
  - `on-stop.sh` (Stop) — ON
  - `pre-bash.sh` (PreToolUse:Bash) — ON
  - `user-prompt-validator.sh` (UserPromptSubmit) — **ON** (filtro de secretos: AWS, GitHub, Anthropic, OpenAI, PEM, Slack)
  - `post-edit-format.sh` (PostToolUse:Edit|Write) — OFF (auto-formato silencioso si hay formatter)
  - `session-start.sh` (SessionStart) — OFF (imprime branch, spec activo, backlog pendiente)
  - `subagent-stop.sh` (SubagentStop) — OFF (log de subagentes en `memory/sessions/subagents.log`)

### Init shell
- **`--non-interactive` / `-y`**: usa env vars `HARNESS_*` como defaults. Habilita los tests E2E.
- **Git opcional**: pregunta primero (default `n`). Si NO → omite todos los permisos `Bash(git *)` del `settings.json` y salta `git init`.
- **Deploy target**: nueva pregunta (`none` / `cloudflare` / `railway` / `vercel` / `manual`). Default `none`.
  - `cloudflare` → agrega `cloudflare-bindings` MCP al `.mcp.json` (`mcp-remote` a `https://bindings.mcp.cloudflare.com/sse`).
  - `railway`    → agrega Railway MCP (`mcp-remote` a `https://mcp.railway.com`).
  - `vercel`     → agrega Vercel MCP (`mcp-remote` a `https://mcp.vercel.com`).
  - `manual` / `none` → sin MCP de deploy.
- `settings.json.allow` ahora incluye permisos para `python -m venv` y `source .venv/bin/activate`.

### Agentes
- **Token economy** explícito en planner/generator/evaluator: Grep/Glob antes de Read, frontmatter primero, confirmar con el usuario antes de bulk reads (>5 archivos o >2000 líneas) o WebSearch.
- **Planner**: paso explícito "Confirm deployment strategy" antes de escribir el spec; escribe sección `## Deployment` en CLAUDE.md; agrega requisitos responsive/`.venv` al spec según el stack.
- **Generator**: lee `memory/backlog.md` además del spec; marca ítems resueltos `- [x]`; convenciones `.venv` (Python) y responsive (web) explícitas.
- **Evaluator-light**: persiste findings en `memory/backlog.md` con prioridades P0/P1/P2 (formato accionable que `/build` consume); valida convenciones del repo (.venv, responsive); activa `.venv` antes de `pytest`.

### Templates
- **`CLAUDE.md.tmpl`**: nueva sección `## Deployment` con `{{DEPLOY_TARGET}}`. Convenciones `.venv` (Python) y responsive (web) explícitas.
- **`HARNESS.md.tmpl`**: lista los 5 commands finales, muestra `DEPLOY_TARGET` en encabezado, diagrama de flujo `/plan → /config-stack → /build ↔ /evaluate → /ship`.
- **Nuevo `backlog.md.tmpl`**: archivo `memory/backlog.md` que se genera al inicializar; sección "TODO manual" + área donde `/evaluate` appendea findings.
- **Fragments** `eval_workflow_A/B.txt` actualizados para reflejar paso de deploy en `/ship`.

### Tests E2E
- **`tests/e2e-scaffold.sh`**: smoke estructural del scaffolder. Verifica creación de archivos, ausencia de los no-seleccionados, validez del JSON, idempotencia (2ª corrida), y variante git=yes. No requiere API key.
- **`tests/e2e-claude.sh`**: invoca Claude Code headless (`claude -p`) sobre el dir scaffoldeado para `/plan` + `/build` y valida que se generó código real. Requiere `ANTHROPIC_API_KEY`. Costo ~$0.10-0.30 por corrida.

## Estructura
```
harness-bundle/
├── init-harness.sh       ← LÓGICA del scaffolder (con --non-interactive)
├── check-skills.sh       ← Pre/post-flight: auditoría de ~/.claude/
├── install-global.sh     ← Symlinks check-skills + init-harness en PATH
├── uninstall-global.sh   ← Revierte instalación global
├── VERSION               ← versión del bundle (1g)
├── MANIFEST.md           ← este archivo
├── CLAUDE.md             ← reglas de trabajo sobre este repo
├── USER_GUIDE.md         ← guía paso a paso
├── harness_strategy.md   ← estrategia (fuente de verdad)
├── tests/                ← E2E tests (scaffold + claude headless)
└── assets/
    ├── agents/           planner, generator, evaluator-light
    ├── commands/         plan, config-stack, build, evaluate, ship  (5)
    ├── hooks/            on-stop, pre-bash, user-prompt-validator, post-edit-format, session-start, subagent-stop
    ├── skills/           3 universales (siempre copiados)
    ├── skill-packs/      librería de packs por stack (vacía al inicio)
    └── templates/        CLAUDE.md, HARNESS.md, backlog.md, etc. + fragments/
```

## Archivos y checksums

| Archivo | Tipo | Checksum (sha256, 12) |
|---|---|---|
| init-harness.sh | lógica | `18a10b50d016` |
| check-skills.sh | lógica | `166998bb283f` |
| install-global.sh | instalador | `626a481c99de` |
| uninstall-global.sh | instalador | `ed19768a1bf1` |
| VERSION | meta | `be191d20627f` |
| tests/e2e-scaffold.sh | test | `c2100975ce7b` |
| tests/e2e-claude.sh | test | `8ca0daec01bf` |
| assets/agents/evaluator-light.md | agente | `a89d9af2db37` |
| assets/agents/generator.md | agente | `7c76e287ae4a` |
| assets/agents/planner.md | agente | `c104e4886529` |
| assets/commands/build.md | command | `f684df3a8ce4` |
| assets/commands/config-stack.md | command | `722329a9e6eb` |
| assets/commands/evaluate.md | command | `d5c664b537aa` |
| assets/commands/plan.md | command | `8adfef7af077` |
| assets/commands/ship.md | command | `24905b0e39b9` |
| assets/hooks/on-stop.sh | hook | `6e9b36b5eb6d` |
| assets/hooks/pre-bash.sh | hook | `a551e12576fb` |
| assets/hooks/user-prompt-validator.sh | hook | `c1b9e8d5bbb7` |
| assets/hooks/post-edit-format.sh | hook | `5e9df629b2ac` |
| assets/hooks/session-start.sh | hook | `8cd1424205af` |
| assets/hooks/subagent-stop.sh | hook | `08ec5b911a68` |
| assets/skill-packs/README.md | doc | `e52a3656dea1` |
| assets/skills/systematic-debugging/SKILL.md | skill | `d85aaea15f86` |
| assets/skills/test-driven-development/SKILL.md | skill | `375b8b3556ab` |
| assets/skills/verification-before-completion/SKILL.md | skill | `7e8c7cd39999` |
| assets/templates/CLAUDE.md.tmpl | template | `eef38d91ca80` |
| assets/templates/HARNESS.md.tmpl | template | `2f2ade8e774e` |
| assets/templates/adr-template.md.tmpl | template | `67f733003f15` |
| assets/templates/architecture.md.tmpl | template | `59ced5d04fff` |
| assets/templates/backlog.md.tmpl | template | `3dc84c8b60c2` |
| assets/templates/decisions.md.tmpl | template | `1019d5790337` |
| assets/templates/env.example.tmpl | template | `d3092e18fcfa` |
| assets/templates/fragments/backlog_A.txt | fragmento | `740fa0b674eb` |
| assets/templates/fragments/backlog_B.txt | fragmento | `86dabb7c7518` |
| assets/templates/fragments/compliance.txt | fragmento | `239799525c75` |
| assets/templates/fragments/eval_agent_line_B.txt | fragmento | `39d97bf49155` |
| assets/templates/fragments/eval_cmd_line_B.txt | fragmento | `780b8abcf2bc` |
| assets/templates/fragments/eval_workflow_A.txt | fragmento | `e9afefcab969` |
| assets/templates/fragments/eval_workflow_B.txt | fragmento | `4df493769bd2` |
| assets/templates/gitignore.tmpl | template | `0d32e330e244` |
| assets/templates/mcp.json.example.tmpl | template | `452e9e4cd41a` |
