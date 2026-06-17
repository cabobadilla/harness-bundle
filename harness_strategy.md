# Agent Harness Engineering con Claude Code
 
**Guía v2.2 — optimizada para Opus 4.5 o superior**
**Arquitectura Planner · Generator · Evaluator**
**Bundle de referencia: harness-bundle v1f**
 
Autor: Chris Bobadilla (con asistencia de Claude)
Audiencia: arquitectos / ingenieros que usan Claude Code con modelos Opus 4.5+ y quieren un patrón production-grade, mínimo y evolutivo.
 
> **Cambio clave vs. v1:** esta versión asume **Opus 4.5 o superior**. Esos modelos eliminaron la "context anxiety" y manejan tareas largas de forma nativa. Por eso el harness es **más simple**: sin context resets, sin sprints obligatorios, y con el evaluador como pieza **condicional**, no por defecto. Se alinea con el paper de Anthropic ["Harness design for long-running application development"](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Labs, mar-2026).
 
---
 
## Tabla de contenidos
 
1. [Principio rector: el harness se simplifica con cada modelo](#1-principio-rector)
2. [La arquitectura Planner · Generator · Evaluator](#2-la-arquitectura-planner--generator--evaluator)
3. [MVP (Opción A) vs. objetivo (Opción B)](#3-mvp-opción-a-vs-objetivo-opción-b)
4. [Modelo mental: las 6 capas](#4-modelo-mental-las-6-capas)
5. [Paso 1 — Fundación](#5-paso-1--fundación)
6. [Paso 2 — Contexto](#6-paso-2--contexto)
7. [Paso 3 — Los tres agentes](#7-paso-3--los-tres-agentes)
8. [Paso 4 — Capacidades (MCPs y Skills)](#8-paso-4--capacidades-mcps-y-skills)
9. [Paso 5 — Guardrails](#9-paso-5--guardrails)
10. [Paso 6 — Evaluación condicional](#10-paso-6--evaluación-condicional)
11. [Plan de implementación (MVP → Opción B)](#11-plan-de-implementación-mvp--opción-b)
12. [Limpieza de configuración: qué desinstalar](#12-limpieza-de-configuración-qué-desinstalar)
13. [Anexo A: el script init-harness-v2.sh](#13-anexo-a-el-script)
14. [Anexo B: variante enterprise / banca](#14-anexo-b-variante-enterprise--banca)
15. [Anexo C: templates listos para copiar](#15-anexo-c-templates-listos-para-copiar)
---
 
## 1. Principio rector
 
> **Cada componente de un harness codifica una asunción sobre lo que el modelo NO puede hacer solo. Esas asunciones caducan a medida que los modelos mejoran.**
 
Esta es la lección central del paper de Anthropic, y es el corazón de esta guía v2.
 
El autor del paper (Prithvi Rajasekaran, Labs) construyó un harness con tres agentes + context resets + sprints, y luego **fue removiendo piezas con cada modelo nuevo**:
 
- Con **Sonnet 4.5**: necesitaba context resets (el modelo sufría "context anxiety" — se auto-limitaba al acercarse a su límite de contexto) + sprints.
- Con **Opus 4.5**: eliminó los context resets. El modelo ya no se auto-limitaba.
- Con **Opus 4.6**: eliminó los sprints. Movió el evaluador a una sola pasada al final.
**Implicación para ti:** como vas a usar **Opus 4.5 o superior**, partes en un punto donde mucho scaffolding ya es innecesario. Tu trabajo NO es construir el harness más completo, sino el más simple que aún te dé lift.
 
La regla operativa que gobierna todo lo demás:
 
> **El evaluador no es una decisión fija de sí/no. Vale el costo cuando la tarea está más allá de lo que el modelo hace confiablemente solo.**
 
---
 
## 2. La arquitectura Planner · Generator · Evaluator
 
El paper se inspira en los **GANs (Generative Adversarial Networks)**: separar quien *genera* de quien *evalúa* produce mejor output que pedirle a un solo agente que haga ambas cosas. Los modelos son notoriamente malos auto-evaluándose: tienden a elogiar su propio trabajo aunque sea mediocre.
 
### Los tres roles
 
```
       ┌──────────────┐
       │   PLANNER    │   prompt de 1-4 frases  →  spec de producto
       │              │   ambicioso en scope, alto nivel
       └──────┬───────┘   NO detalla implementación técnica
              │
              │  spec (archivo)
              ▼
       ┌──────────────┐
       │  GENERATOR   │   implementa el spec, feature por feature
       │              │   se auto-evalúa antes de entregar
       │              │   tiene git
       └──────┬───────┘
              │
              │  app levantada + diff
              ▼
       ┌──────────────┐
       │  EVALUATOR   │   (CONDICIONAL — solo si la tarea lo amerita)
       │              │   clickea la app como usuario real (Playwright)
       │              │   escéptico, con thresholds duros
       └──────┬───────┘   si un criterio falla → feedback al generator
              │
              │  feedback (archivo)
              └──────────► vuelve al GENERATOR
```
 
### Por qué cada agente existe
 
| Agente | Problema que resuelve | Detalle del paper |
|---|---|---|
| **Planner** | El generator solo, con un prompt crudo, sub-escopea: empieza a construir sin especificar y produce una app menos rica. | Toma 1-4 frases, expande a spec completa. Ambicioso. **Alto nivel** — si detalla implementación y se equivoca, el error se propaga downstream. |
| **Generator** | — (es el que hace el trabajo) | Trabaja feature por feature. Se auto-evalúa antes de pasar a QA. Stack del paper: React + Vite + FastAPI + SQLite/Postgres. |
| **Evaluator** | Los agentes se auto-elogian. Apps "se ven bien" pero tienen bugs reales al usarlas. | Usa **Playwright MCP** para navegar la app como usuario. Tuneado para ser **escéptico**. Cada criterio tiene threshold duro. |
 
### El insight contra-intuitivo del evaluator
 
Separar generador de evaluador **no elimina** la indulgencia por sí solo — el evaluador sigue siendo un LLM inclinado a ser generoso con output de otro LLM. Pero **tunear un evaluador standalone para ser escéptico es mucho más tratable** que hacer que el generador sea crítico de su propio trabajo. Y una vez que existe feedback externo, el generador tiene algo concreto contra qué iterar.
 
---
 
## 3. MVP (Opción A) vs. objetivo (Opción B)
 
Esta guía adopta un enfoque **evolutivo**: empiezas con el mínimo y agregas el evaluador solo cuando una tarea real te demuestre que lo necesitas.
 
### Opción A — MVP: Planner + Generator
 
```
PLANNER  →  GENERATOR  →  (output)
```
 
- **Dos agentes.** El planner expande el prompt; el generator implementa.
- **Sin evaluador.** Confías en la capacidad nativa de Opus 4.5+.
- **Cuándo:** la mayoría de tu trabajo diario — features, refactors, bug fixes, tareas dentro de lo que el modelo maneja bien solo.
- **Costo:** mínimo. En el paper, el planner cuesta ~$0.46; el resto es build.
- **Esfuerzo de setup:** casi cero — el `planner` subagent ya existe en el harness.
### Opción B — Objetivo: Planner + Generator + Evaluator condicional
 
```
PLANNER  →  GENERATOR  ⇄  EVALUATOR  →  (output)
                       (loop condicional)
```
 
- **Tres agentes.** El evaluador se invoca **solo cuando la tarea es ambiciosa** (apps full-stack con frontend, o cuando "se ve bien pero no sé si funciona").
- **El evaluador ejecuta la app** con Playwright MCP, no solo lee el diff.
- **Cuándo:** apps con UI, entregables a cliente, builds donde un bug sutil sería caro.
- **Costo:** +$3-4 por pasada de QA (cifras del paper).
### La regla de decisión
 
```
¿La tarea está dentro de lo que Opus 4.5+ hace confiablemente solo?
├─ SÍ  → Opción A (planner + generator). No invoques evaluador.
└─ NO  → Opción B (agrega evaluator). Vale el costo.
 
Señales de "NO" (usa evaluador):
  • App con frontend interactivo
  • Entregable a cliente / producción
  • "Se ve bien pero no sé si realmente funciona"
  • Lógica con muchos edge cases (pagos, validaciones)
```
 
**Tu plan:** parte con A como default. Activa B cuando duela. No construyas C (el loop completo multi-hora autónomo) hasta que tengas un caso de uso de generación casi-autónoma de apps.
 
---
 
## 4. Modelo mental: las 6 capas
 
Respecto a v1, esta versión **colapsa una capa** (reusabilidad se difiere) y reordena en torno a los tres agentes.
 
```
┌─────────────────────────────────────────────┐
│ 6. Evaluación        evaluator condicional   │  ← Opción B
├─────────────────────────────────────────────┤
│ 5. Guardrails        hooks + permissions     │
├─────────────────────────────────────────────┤
│ 4. Capacidades       MCPs + skills           │
├─────────────────────────────────────────────┤
│ 3. Los 3 agentes     planner/generator/eval  │  ← corazón v2
├─────────────────────────────────────────────┤
│ 2. Contexto          CLAUDE.md + memoria     │
├─────────────────────────────────────────────┤
│ 1. Fundación         repo structure          │
└─────────────────────────────────────────────┘
```
 
Reglas:
 
1. **MVP = capas 1-3 (Opción A).** Con eso ya tienes un harness funcional.
2. **Opción B agrega capas 4-6** (Playwright MCP + guardrails + evaluador).
3. **Re-examina el harness con cada modelo nuevo.** Quita lo que dejó de ser load-bearing. Esta no es una regla decorativa: es el método del paper.
---
 
## 5. Paso 1 — Fundación
 
### 5.1 Estructura del repo
 
```
mi-proyecto/
├── CLAUDE.md                    # contrato del proyecto (capa 2)
├── .mcp.json                    # MCPs declarados (capa 4)
├── .claude/
│   ├── settings.json            # permisos + hooks (capa 5)
│   ├── settings.local.json      # overrides locales (gitignored)
│   ├── commands/                # slash commands (capa 3)
│   │   ├── plan.md
│   │   ├── build.md
│   │   ├── evaluate.md          # solo Opción B
│   │   └── ship.md
│   ├── agents/                  # los 3 agentes (capa 3)
│   │   ├── planner.md
│   │   ├── generator.md
│   │   └── evaluator.md         # solo Opción B
│   ├── skills/                  # skills del proyecto (capa 4)
│   └── hooks/                   # scripts de hooks (capa 5)
├── docs/
│   ├── architecture.md
│   └── decisions/               # ADRs
├── memory/                      # memoria persistente (capa 2)
│   ├── decisions.md
│   ├── specs/                   # specs generados por el planner
│   └── evaluations/             # reportes del evaluador (Opción B)
└── .gitignore
```
 
> **Nota v2:** desaparece `evals/` como carpeta de runner headless separado. La evaluación ahora vive *in-loop* vía el agente evaluator (capa 6), no como un batch post-hoc. Si quieres evals de regresión batch, agrégalos después; no son parte del MVP.
 
### 5.2 `.gitignore` mínimo
 
```gitignore
# Claude Code locals
.claude/settings.local.json
memory/evaluations/
 
# Secrets
.env
.env.*
!.env.example
 
# Build artifacts
node_modules/
__pycache__/
.venv/
dist/
build/
```
 
**Criterio de aceptación capa 1:** abres el repo con Claude Code y reconoce el CLAUDE.md sin errores.
 
---
 
## 6. Paso 2 — Contexto
 
El CLAUDE.md es un **prompt de sistema persistente**, no un README.
 
### 6.1 Estructura recomendada
 
```markdown
# Proyecto: <nombre>
 
## Modelo objetivo
Este proyecto está optimizado para Opus 4.5 o superior.
NO implementar context resets ni decomposición en sprints por defecto:
los modelos actuales manejan tareas largas nativamente.
 
## Misión
Una sola frase. Qué hace el sistema, para quién.
 
## Arquitectura sintética
- Stack: <lenguajes, frameworks>
- Detalle en `@docs/architecture.md`
 
## Workflow de agentes
1. `/plan <objetivo>`  → planner expande a spec en memory/specs/
2. `/build`            → generator implementa el spec
3. `/evaluate`         → SOLO si la tarea es ambiciosa (Opción B)
4. `/ship`             → verificación + commit convencional
 
## Política de evaluación
- Tareas simples/medias → confiar en el generator (Opción A).
- Apps con UI, entregables a cliente, lógica con edge cases → invocar /evaluate (Opción B).
 
## Convenciones no negociables
- Conventional commits
- Tests para lógica de negocio
- Patrones prohibidos: <según stack>
 
## Política de plugins externos
NO usar automáticamente plugins de la comunidad (superpowers, ralph-loop,
gstack, etc.). El workflow de este proyecto se define SOLO por los agentes
y commands en .claude/. Si una tarea pareciera beneficiarse de un plugin
externo, PREGUNTAR antes de invocarlo.
 
## Referencias persistentes
- @memory/decisions.md
- @docs/architecture.md
```
 
### 6.2 Memoria persistente (append-and-reread)
 
`memory/decisions.md` con bitácora de decisiones. Cada decisión arquitectónica se escribe ahí; en la siguiente sesión Claude la lee vía `@memory/decisions.md`. Reemplaza re-explicar contexto.
 
**Criterio de aceptación capa 2:** abres sesión nueva, preguntas "¿qué hicimos la última vez?" y Claude responde sin que hayas explicado nada.
 
---
 
## 7. Paso 3 — Los tres agentes
 
Este es el corazón de la v2. Carpeta `.claude/agents/`.
 
### 7.1 `planner.md`
 
```markdown
---
name: planner
description: Use proactively at the start of any non-trivial build. Expands a short prompt into a full product spec. Never edits code.
tools: Read, Grep, Glob, WebSearch
---
 
You are the product planner. You take a 1-4 sentence prompt and expand it
into a complete product spec.
 
Principles (from Anthropic's harness research):
- Be AMBITIOUS about scope. Aim for a rich, complete product.
- Stay HIGH-LEVEL. Describe product context and high-level technical
  direction — NOT granular implementation details. If you over-specify
  technical details and get one wrong, the error cascades downstream.
- Constrain the deliverables, let the generator figure out the path.
- Look for opportunities to weave in AI features where they add value.
 
Process:
1. Read CLAUDE.md and @memory/decisions.md.
2. Expand the prompt into a spec with:
   - Overview (what, for whom, why)
   - Feature list with user stories
   - High-level data model
   - High-level technical direction (stack, boundaries)
3. Save to memory/specs/<slug>.md.
4. Never edit code. Never implement.
```
 
### 7.2 `generator.md`
 
```markdown
---
name: generator
description: Implements a spec produced by the planner, feature by feature. Self-evaluates before handing off.
tools: Read, Grep, Glob, Edit, Write, Bash
---
 
You are the builder. You implement the spec from memory/specs/.
 
Principles:
- Work one feature at a time. Don't try to build everything at once.
- Use git for version control. Commit at meaningful checkpoints.
- SELF-EVALUATE before declaring a feature done: run tests, click through
  your own work mentally, check against the spec.
- For Opus 4.5+: you do NOT need sprint decomposition or context resets.
  Work coherently through the build. Automatic compaction handles context.
 
Process:
1. Read the spec from memory/specs/<slug>.md.
2. Read CLAUDE.md for conventions.
3. Implement feature by feature.
4. After each meaningful chunk: run tests, verify against spec, commit.
5. When the build is ready, summarize what was built and what remains.
```
 
### 7.3 `evaluator.md` — solo Opción B
 
```markdown
---
name: evaluator
description: Use to QA a running application by interacting with it like a real user. Skeptical by design. Only invoke for ambitious tasks beyond what the model does reliably solo.
tools: Read, Grep, Glob, Bash, mcp__playwright__*
---
 
You are a SKEPTICAL QA evaluator. Out of the box, LLMs are poor QA agents:
they find real issues, then talk themselves into approving anyway. Do NOT
do that. Your job is to find what's broken.
 
Principles:
- Click through the RUNNING application like a real user would, using
  Playwright. Don't grade a static screenshot — interact with the page.
- Test UI features, API endpoints, and database states.
- Probe EDGE CASES, not just the happy path.
- Be specific: cite file:line, exact reproduction steps, expected vs actual.
 
Grading criteria (each has a HARD threshold — if any fails, the build fails):
- Product depth: does it have real interactive features, not display-only stubs?
- Functionality: do the core interactions actually work?
- Visual design: coherent identity, not generic "AI slop"?
- Code quality: sound structure, no obvious smells?
 
Process:
1. Confirm the app is running (ask the generator to start it if needed).
2. Navigate it with Playwright. Screenshot. Interact. Probe.
3. For each criterion, score and justify with concrete evidence.
4. File specific bugs: criterion, finding, file:line, repro.
5. Write the report to memory/evaluations/<slug>-<date>.md.
6. PASS only if every criterion clears its threshold.
```
 
### 7.4 Slash commands
 
`.claude/commands/`:
 
- **`/plan <objetivo>`** → invoca `planner`, guarda spec en `memory/specs/`.
- **`/build`** → invoca `generator` sobre el spec más reciente.
- **`/evaluate`** → (Opción B) invoca `evaluator` sobre la app levantada.
- **`/ship`** → lint + tests + secret-scan + conventional commit (no push).
**Criterio de aceptación capa 3:** `/plan "una app de notas"` produce un spec rico en `memory/specs/`, y `/build` lo implementa.
 
---
 
## 8. Paso 4 — Capacidades (MCPs y Skills)
 
### 8.1 Árbol de decisión
 
```
¿Acceder a un sistema externo (DB, SaaS, API)?
├─ SÍ → MCP server
└─ NO → ¿Procedimiento repetible con templates/archivos?
        ├─ SÍ → Skill
        └─ NO → Tool nativo (Bash, Edit, Read)
```
 
### 8.2 MCPs base
 
| MCP | Para qué | MVP (A) | Opción B |
|---|---|---|---|
| **github** | Issues, PRs | opcional | opcional |
| **filesystem** | Paths fuera del repo | opcional | opcional |
| **postgres/sqlite** | Inspección de DB | opcional | opcional |
| **playwright** | Navegar la app como usuario | **NO** | **SÍ — requerido por el evaluator** |
 
> **Sobre Playwright:** en la limpieza de configuración (sección 12) verás que Playwright se mueve de "desinstalar" a **"mantener para el evaluator"**. Es la única dependencia que la Opción B reintroduce conscientemente. No lo dejes auto-triggereando — actívalo solo dentro de `/evaluate`.
 
### 8.3 Skills reutilizables
 
Tres skills canónicos del harness — siempre copiados al `.claude/skills/` del proyecto (versionados, portables):
 
| Skill | Cuándo se aplica |
|---|---|
| `test-driven-development` | Antes de implementar lógica no trivial. |
| `systematic-debugging` | Cuando aparece un bug, test rojo o "no funciona". |
| `verification-before-completion` | Antes de declarar "listo / hecho / fixed". |
 
Para banca / regulados, agregar: `banking-compliance` (opcional, ver Anexo B).
 
### 8.4 Skill-packs por stack y `/configure-stack`
 
Hay dos niveles de skills:
 
| Nivel | Cuándo se copian al proyecto | Origen |
|---|---|---|
| **Universales** (TDD, debugging, verification) | Siempre, durante `init-harness` | `assets/skills/` |
| **Skill-packs por stack** (ej: react-component-pattern, fastapi-endpoint) | Después del `/plan`, vía `/configure-stack` | `assets/skill-packs/` (librería del bundle, vacía al inicio) |
 
**Por qué esta separación:** el planner decide el stack alto nivel en `/plan` — antes de ese momento NO sabemos qué packs aplican. Adelantar packs por las dudas contamina el contexto.
 
**Flujo:** `/plan` → planner actualiza CLAUDE.md con el stack → `/configure-stack` lee el stack del spec, busca packs en bundle → global → reporta missing → `/build`.
 
**Si un pack solicitado no existe en ningún lado:** `/configure-stack` ofrece (a) skip y anotar en decisions.md, (b) crear stub vacío, (c) abortar para que el usuario lo cree y re-corra.
 
La librería arranca **vacía a propósito**. Se llena cuando un caso real lo justifica (no por especulación).
 
### 8.5 Wiring de skills (cómo se conectan a los agentes)
 
Este es un detalle de implementación crítico y a menudo invisible: **los subagentes (planner, generator, evaluator) NO tienen la herramienta `Skill`** — solo ven los tools declarados en su frontmatter. Por eso el harness conecta skills en tres capas, no una:
 
| Capa | Rol | Por qué allí |
|---|---|---|
| **CLAUDE.md** | Contrato: declara el mapeo fase→skill. | Es el único archivo cargado en TODOS los contextos (main + subagentes). Policy, no enforcement. |
| **Slash commands** (`/ship`, `/build`) | Punto de invocación explícito: `"Invoca el skill X vía la herramienta Skill"`. | Los `/commands` corren en el contexto principal, que SÍ tiene `Skill`. Es la compuerta determinística. |
| **Agente** (`generator.md`) | Refuerzo procedural: `"Lee y aplica .claude/skills/<skill>/SKILL.md"`. | El agente tiene `Read`. Lee la procedura por path en vez de duplicarla. |
 
Consecuencia operativa: los skills se copian SIEMPRE al `.claude/skills/` del proyecto. Versiones globales del usuario no son load-bearing — los agents apuntan a paths locales para garantizar portabilidad y reproducibilidad.
 
**Criterio de aceptación capa 4:** corres `/ship` y, antes de cualquier otro paso, el agente principal invoca `Skill(verification-before-completion)` y reporta la checklist con evidencia.
 
---
 
## 9. Paso 5 — Guardrails
 
### 9.1 Permissions en `.claude/settings.json`
 
```json
{
  "permissions": {
    "allow": [
      "Bash(git diff:*)", "Bash(git status:*)", "Bash(git log:*)",
      "Bash(npm test:*)", "Bash(npm run:*)", "Bash(pytest:*)",
      "Read(./**)",
      "Edit(./src/**)", "Edit(./tests/**)", "Edit(./docs/**)", "Edit(./memory/**)"
    ],
    "ask": [
      "Bash(git push:*)", "Bash(npm install:*)", "Bash(pip install:*)"
    ],
    "deny": [
      "Bash(rm -rf:*)", "Bash(curl:*)", "Bash(wget:*)",
      "Read(./.env*)", "Read(./secrets/**)", "Edit(./.env*)"
    ]
  }
}
```
 
### 9.2 Hooks recomendados
 
- **PreToolUse(Bash)** → bloquea comandos peligrosos (rm -rf, curl|sh, sudo).
- **Stop** → guarda resumen de sesión a `memory/sessions/`.
**Criterio de aceptación capa 5:** intentas `rm -rf` o leer `.env` y el harness lo bloquea.
 
---
 
## 10. Paso 6 — Evaluación condicional
 
Esta capa **solo aplica a la Opción B**. Es el aporte central del paper.
 
### 10.1 Eval in-loop vs. eval post-hoc
 
| | Post-hoc (v1) | In-loop (v2, paper) |
|---|---|---|
| Cuándo corre | Batch, después del build | Durante el build, como agente |
| Qué hace | Corre cases headless, guarda JSON | Clickea la app viva con Playwright |
| Detecta | Regresiones conocidas | Bugs reales de UX que "se ven bien" |
| Costo | Bajo | +$3-4 por pasada |
 
La v2 prioriza **in-loop** porque captura la clase de bug que el paper demuestra: apps que parecen funcionar pero cuyo botón principal no responde.
 
### 10.2 Los 4 criterios con threshold
 
Tomados del paper, adaptados:
 
1. **Product depth** — ¿features interactivas reales, no stubs display-only?
2. **Functionality** — ¿las interacciones core funcionan de verdad?
3. **Visual design** — ¿identidad coherente, no "AI slop" genérico?
4. **Code quality** — ¿estructura sólida?
Cada uno con umbral duro. Si uno falla, el build falla y el generator recibe feedback específico.
 
### 10.3 Cómo tunear el evaluator
 
El paper es claro: **out of the box, Claude es mal QA**. Identifica issues legítimos y luego se convence de aprobarlos igual. El loop de tuning:
 
1. Lee los logs del evaluator.
2. Encuentra casos donde su juicio difiere del tuyo.
3. Actualiza el prompt del evaluator para esos casos.
4. Repite hasta que califique de forma razonable.
**Criterio de aceptación capa 6:** corres `/evaluate` sobre una app con un bug intencional de UI y el evaluator lo detecta y reporta con file:line.
 
---
 
## 11. Plan de implementación (MVP → Opción B)
 
| Fase | Foco | Entregable | Criterio de éxito |
|---|---|---|---|
| **0 — Limpieza** | Auditar `~/.claude/` con `check-skills.sh` (sección 12) | Config limpia | `check-skills.sh` termina con "Entorno alineado" o solo DEFERs conscientes |
| **1 — MVP (Opción A)** | Capas 1-3 | Template + CLAUDE.md + planner + generator + 3 skills copiados | `/plan`→`/build` produce app coherente |
| **2 — Guardrails** | Capas 4-5 | Permissions + hooks + secret-scan + wiring de skills (8.4) | `rm -rf` y `.env` bloqueados; `/ship` invoca verification skill como paso 0 |
| **3 — Opción B** | Capa 6 | evaluator + Playwright MCP + `/evaluate` | bug de UI intencional detectado |
| **4 — Iterar** | Tuning | evaluator calibrado | falsos positivos/negativos bajo control |
| **5 — Post-flight** | Re-correr `check-skills.sh` | Verificar que nada se "encendió" tras el bootstrap | salida idéntica o más limpia que Fase 0 |
 
**Ritmo:** Fase 1 en un día. Fases 2-3 en una semana. Fase 4 es continua.
 
**Regla de oro v2:** vive en la Opción A todo lo que puedas. Sube a B solo cuando una tarea real te muestre que el generator solo no basta. No al revés.
 
---
 
## 12. Limpieza de configuración: qué desinstalar
 
Adoptar este harness implica **quitar** los plugins de la comunidad que compiten con tus agentes. Basado en tu configuración actual (`code_config.md`).
 
> **Automatización:** el bundle entrega `check-skills.sh` — un auditor independiente que cruza `~/.claude/skills/`, `~/.claude/plugins/installed_plugins.json` y `~/.claude/settings.json` contra la tabla 12.1-12.3 de abajo. Read-only por default; acción destructiva opt-in con `--suggest` o `--interactive` (este último hace backup automático de `settings.json` antes de tocar nada). Corrélo ANTES (Fase 0) y DESPUÉS (Fase 5) del scaffolding — el segundo run confirma que nada se "encendió" por accidente.
 
### 12.1 Desinstalar inmediatamente
 
| Plugin | Razón |
|---|---|
| **legalzoom** | Uso único. Resolviste el caso con código propio. Drop. |
| **superpowers** | ~50 skills auto-triggereables que contradicen tu CLAUDE.md. Portas 4-5 patrones al harness (ver abajo) y desinstalas. Es el de mayor ROI quitar. |
| **commit-commands** | `commit`/`commit-push-pr` ya viven en tu `/ship`. `clean_gone` son 3 líneas de bash. |
| **github** (plugin) | Tienes MCP de github (mejor integración). Redundante. |
| **frontend-design** (plugin) | Hay un skill `frontend-design` built-in equivalente. Además el planner del paper lo lee como skill puntual, no necesita el plugin permanente. |
 
### 12.2 Mantener
 
| Plugin | Razón |
|---|---|
| **playwright** | ⭐ **CAMBIO vs. plan anterior:** ya NO se desinstala. El `evaluator` de la Opción B lo necesita para navegar la app. Mantener, pero sin auto-trigger — se activa solo dentro de `/evaluate`. |
| **railway** | Tu plataforma real de deploy. |
| **cloudflare** | Útil acotado; ya tienes user skill `cloudflare-deploy`. |
| **skill-creator** | ROI claro mientras construyes el harness. |
 
### 12.3 Probar 1 semana y decidir
 
| Plugin | Acción |
|---|---|
| **ralph-loop** | El paper menciona el método "Ralph Wiggum" pero NO lo usa — usa la arquitectura estructurada de 3 agentes. Tu `/plan`→`/build`→`/evaluate` lo reemplaza. Si en 1 semana no lo extrañas, desinstalar. |
 
### 12.4 Patrones de superpowers a portar antes de desinstalar
 
Estos 4-5 patrones valen la pena como skills/commands de tu harness (no como plugin):
 
| Patrón superpowers | Mapeo en harness |
|---|---|
| `freeze` / `guard` / `careful` | command `/freeze` + hook `freeze-guard.sh` |
| `systematic-debugging` | skill `.claude/skills/systematic-debugging/` |
| `test-driven-development` | skill `.claude/skills/test-driven-development/` |
| `verification-before-completion` | skill, invocado como paso 0 de `/ship` |
| `subagent-driven-development` | **ya cubierto** por la arquitectura planner/generator/evaluator |
 
### 12.5 Lo que NO se toca: MCPs
 
Los MCPs (M365, Notion, Knowledge Search BCG, Navi, Figma, Zoom, Cloudflare) exponen tools, no auto-triggerean skills. Déjalos. La excepción es Playwright MCP, que ahora se mantiene para el evaluator.
 
### 12.6 Ajuste a tu `~/.claude/settings.json` global
 
Hoy solo tienes `Bash(rsync:*)` en allow, por eso Claude pregunta en cada `git status`. Agrega al global:
 
```json
{
  "permissions": {
    "allow": [
      "Bash(rsync:*)", "Bash(git diff:*)", "Bash(git status:*)",
      "Bash(git log:*)", "Bash(ls:*)", "Read(./**)"
    ],
    "deny": ["Bash(rm -rf /:*)", "Bash(sudo:*)"]
  }
}
```
 
### 12.7 Resultado esperado
 
- De 10 plugins → 4 mantenidos (railway, cloudflare, skill-creator, playwright) + 4 patrones portados.
- De 50+ skills auto-triggereables → ~5 curados por proyecto.
- CLAUDE.md como contrato real, sin contraprogramación.
- Harness portable a clientes enterprise (sin dependencias comunitarias salvo Playwright, que es estándar).
---
 
## 13. Anexo A: los scripts del bundle
 
El bundle (v1e) entrega DOS scripts independientes:
 
### 13.1 `check-skills.sh` — auditoría de `~/.claude/`
 
Pre-flight (Fase 0) y post-flight (Fase 5). Read-only por default.
 
```bash
chmod +x check-skills.sh
./check-skills.sh                # solo reporta
./check-skills.sh --suggest      # imprime comandos sin ejecutarlos
./check-skills.sh --interactive  # ejecuta con confirmación 1-a-1 + backup
```
 
Cruza tu entorno contra la tabla 12.1-12.3 y reporta KEEP / DROP / DEFER por plugin habilitado.
 
### 13.2 `init-harness.sh` — bootstrap del proyecto
 
Materializa las capas 1-5 (Opción A o B). Cubre Nivel C como backlog (Playwright todavía manual).
 
```bash
chmod +x init-harness.sh
./init-harness.sh ./mi-proyecto-nuevo
```
 
Te pregunta: tipo de solución (App completa / Flask listo), nombre, misión, stack, tipo de proyecto (personal / enterprise / regulado), **arquitectura (A o B)**, MCPs (github / postgres) y hooks. Es **idempotente**: re-correrlo no destruye customizaciones en `CLAUDE.md`, `.mcp.json` ni `.claude/settings.json`.
 
**Lo que NO pregunta:** la copia de los 3 skills canónicos. Se copian SIEMPRE al `.claude/skills/` del proyecto porque los agents y commands los referencian por path (ver §8.4). Esta decisión hace que el proyecto sea portable: no depende del `~/.claude/skills/` del usuario.
 
---
 
## 14. Anexo B: variante enterprise / banca
 
Para clientes regulados, agrega al CLAUDE.md secciones de `## Compliance`, `## Datos sensibles`, `## Sistemas regulados`. En permissions: `deny` para paths con datos de clientes, `ask` para todo lo que toque sistemas conectados al core.
 
**Sobre el evaluator en banca:** el evaluator con Playwright navega apps. En banca, asegúrate de que navegue solo entornos de **staging con datos sintéticos**, nunca producción ni datos reales de clientes.
 
Patrón seguro de MCPs: lecturas vía MCP read-only, escrituras vía backend local con confirmación humana.
 
---
 
## 15. Anexo C: templates listos para copiar
 
### CLAUDE.md mínimo (Opción A)
 
```markdown
# Proyecto: __PROJECT_NAME__
 
## Modelo objetivo
Opus 4.5+. Sin context resets, sin sprints obligatorios.
 
## Misión
__ONE_LINE_MISSION__
 
## Stack
__STACK__
 
## Workflow de agentes
1. /plan <objetivo>  → spec en memory/specs/
2. /build            → implementa
3. /evaluate         → SOLO si la tarea es ambiciosa
4. /ship             → commit convencional
 
## Skills requeridos (mapeo fase → skill)
| Fase / disparador | Skill | Quién lo invoca |
|---|---|---|
| Antes de implementar lógica no trivial | `test-driven-development` | `/build` + generator |
| Bug, test rojo, "no funciona" | `systematic-debugging` | generator + main |
| Antes de declarar "listo / hecho" | `verification-before-completion` | `/ship` (paso 0) + generator |
 
Subagentes NO tienen `Skill` tool — leen `.claude/skills/<skill>/SKILL.md` por path.
 
## Política de plugins externos
No usar plugins de comunidad automáticamente. Workflow definido solo por .claude/.
 
## Referencias
- @memory/decisions.md
- @docs/architecture.md
```
 
### Tabla de auditoría de plugins (para memory/decisions.md)
 
```markdown
## Auditoría plugins — YYYY-MM-DD
| Plugin | Veredicto | Acción |
|---|---|---|
| legalzoom | Drop | desinstalar |
| superpowers | Port→Drop | portar 4 patrones, desinstalar |
| commit-commands | Drop | /ship cubre |
| github (plugin) | Drop | usar MCP |
| frontend-design (plugin) | Drop | built-in equivalente |
| playwright | Keep | requerido por evaluator |
| railway | Keep | plataforma deploy |
| cloudflare | Keep | acotado |
| skill-creator | Keep | construcción harness |
| ralph-loop | Defer 1 sem | arquitectura 3-agentes reemplaza |
```
 
---
 
## Cierre
 
La regla más importante de la v2, directa del paper:
 
> **Re-examina el harness con cada modelo nuevo. Quita lo que dejó de ser load-bearing. Agrega lo que el nuevo modelo recién hace posible.**
 
El espacio de harnesses interesantes no se encoge cuando los modelos mejoran — **se mueve**. Tu trabajo como ingeniero es seguir encontrando la próxima combinación útil.
 
**Próximos pasos:**
 
1. Ejecuta la limpieza de configuración (sección 12).
2. Corre `init-harness-v2.sh` eligiendo Opción A.
3. Vive en A una semana en un proyecto real.
4. Sube a B cuando una tarea te muestre que el generator solo no basta.
5. Anota en `memory/decisions.md` qué piezas resultaron load-bearing.
---
*Versión 2.1 — Junio 2026 · Optimizada para Opus 4.5+ · Alineada con Anthropic Labs harness research*
*Cambios v2.0 → v2.1: §8.4 (wiring de skills en 3 capas), §11 (Fase 5 post-flight), §12 (referencia a check-skills.sh), §13 (dos scripts: check-skills.sh + init-harness.sh; skills siempre copiados), §15 (CLAUDE.md mínimo incluye sección "Skills requeridos").*
 
*Cambios v2.1 → v2.2: §8.4 nuevo (skill-packs por stack y `/configure-stack`), §8.5 renumerado (era §8.4). El init-harness ya no pregunta STACK — lo decide el planner. Workflow: `/plan → /configure-stack → /build → /evaluate? → /ship`. Eliminado el scaffold Flask del bundle: el esqueleto generado es 100% stack-agnóstico; cualquier código de aplicación lo escribe el generator. Skill discovery dinámico en el generator (lista `.claude/skills/`, no hardcodea nombres).*