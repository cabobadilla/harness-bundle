# MANIFEST — Harness Bundle

**Bundle version:** `1f`
**Generado:** 2026-06-17

La shell (`init-harness.sh`) contiene la LÓGICA. Los `assets/` contienen el CONTENIDO estático.
Editar un asset no requiere tocar la shell. Tras editar, actualiza su checksum con:
`shasum -a 256 <archivo> | cut -c1-12`

## Cambios v1e → v1f
- **Eliminada la pregunta STACK** del init-harness. STACK queda como `<COMPLETAR>` en CLAUDE.md hasta que el planner lo defina en `/plan`. Alinea la shell con §7.1 de la estrategia (planner decide stack alto nivel).
- **MISSION enriquecido**: ahora pide 1-2 frases con instrucciones explícitas ("qué hace, para quién"). El foco se desplaza de configurar stack a articular bien el objetivo (mejor contexto para el planner).
- **Nuevo comando `/configure-stack`** (`assets/commands/configure-stack.md`): copiado a todo proyecto. Detecta el stack del spec, busca skill-packs en bundle → global → reporta missing con 3 opciones (skip/stub/abort).
- **Nueva librería `assets/skill-packs/`** (vacía a propósito). README explica estructura, cuándo agregar packs, y cómo `/configure-stack` los usa.
- **Workflow renumerado**: `1.plan → 2.configure-stack → 3.build → 4.evaluate (B) → 4|5.ship`. Fragments `eval_workflow_{A,B}.txt` actualizados.
- **`planner.md`** actualizado: ahora actualiza explícitamente la sección Stack de CLAUDE.md y cierra recomendando `/configure-stack`.
- **`HARNESS.md.tmpl`** lista el nuevo comando.
- **Skill discovery dinámico en el generator**: el prompt ya NO hardcodea los 3 skills universales como paths fijos. El generator lista `.claude/skills/`, lee los frontmatter, y aplica el skill que matchee con su paso actual. Los packs que `/configure-stack` agrega quedan automáticamente activos sin tocar prompts.
- **`CLAUDE.md.tmpl` "Skills"** reformulado de tabla fija a política + lista universal de referencia. La verdad operativa es `.claude/skills/` (el contenido del directorio).
- **Eliminado `assets/scaffolds/` (Flask scaffold)** y la pregunta "Tipo de solución". Contradice la decisión de v1f (stack lo decide el planner, no el shell). El usuario que quiera Flask lo obtiene vía `/plan "web simple con formulario"` → planner elige Flask → `/build` lo genera. Quitamos 5 archivos + la rama `WANT_FLASK` del init.

## Cambios v1d → v1e
- Fix: `inject_block` ahora usa archivo temporal + `getline` (compatible con BSD awk en macOS).
- Fix: `render_asset`/`copy_asset` retornan 0 en "ya existe" → idempotencia real.
- Fix: `.mcp.json` y `.claude/settings.json` respetan idempotencia (no se sobreescriben).
- Cambio: skills se copian SIEMPRE al proyecto (pregunta eliminada). Son referenciados por path desde agents/commands.
- Wiring: `CLAUDE.md.tmpl` declara mapeo fase→skill. `commands/ship.md` invoca `verification-before-completion` como paso 0. `commands/build.md` sugiere TDD. `agents/generator.md` lee SKILL.md por path en cada fase.
- Nuevo: `check-skills.sh` (script independiente, audita `~/.claude/` contra §12 de la estrategia).
- Nuevo: `install-global.sh` / `uninstall-global.sh` — exponen `check-skills` y `init-harness` como comandos globales vía symlinks (no copias), idempotentes, no destructivos en colisiones. Soportan `--only` para instalar uno solo.
- Fix: `init-harness.sh` ahora resuelve symlinks para encontrar `assets/` cuando se invoca como `init-harness` desde PATH (loop manual porque BSD readlink en macOS no tiene `-f`).

## Estructura
```
harness-bundle/
├── init-harness.sh       ← LÓGICA del scaffolder
├── check-skills.sh       ← Pre/post-flight: auditoría de ~/.claude/
├── install-global.sh     ← Expone check-skills + init-harness como symlinks globales
├── uninstall-global.sh   ← Revierte la instalación global
├── VERSION               ← versión del bundle
├── MANIFEST.md           ← este archivo
├── CLAUDE.md             ← reglas de trabajo sobre este repo
├── USER_GUIDE.md         ← guía paso a paso
├── harness_strategy.md   ← estrategia (fuente de verdad)
└── assets/               ← CONTENIDO editable sin tocar la shell
    ├── agents/           prompts de planner, generator, evaluator
    ├── commands/         slash commands (plan, configure-stack, build, ship, ...)
    ├── hooks/            pre-bash, on-stop, freeze-guard
    ├── skills/           3 skills universales (siempre copiados al proyecto)
    ├── skill-packs/      librería de packs por stack (vacía al inicio, crece con uso)
    └── templates/        CLAUDE.md, HARNESS.md, etc. + fragments/
```

## Archivos y checksums

| Archivo | Tipo | Checksum (sha256, 12) |
|---|---|---|
| init-harness.sh | lógica | `345b41e3bb0e` |
| check-skills.sh | lógica | `166998bb283f` |
| install-global.sh | instalador | `626a481c99de` |
| uninstall-global.sh | instalador | `ed19768a1bf1` |
| VERSION | meta | `71063fefaab7` |
| assets/agents/evaluator-light.md | agente | `c8aebeb9a70b` |
| assets/agents/generator.md | agente | `9517cae202c7` |
| assets/agents/planner.md | agente | `c3d70425b2f3` |
| assets/commands/build.md | command | `5d423986de41` |
| assets/commands/configure-stack.md | command | `2777e876330e` |
| assets/commands/evaluate.md | command | `b60685ff95e3` |
| assets/commands/freeze.md | command | `fed1c2eee0d5` |
| assets/commands/plan.md | command | `8adfef7af077` |
| assets/commands/ship.md | command | `0b446ae12aaa` |
| assets/commands/unfreeze.md | command | `0cdc11176617` |
| assets/hooks/freeze-guard.sh | hook | `383027521333` |
| assets/hooks/on-stop.sh | hook | `6e9b36b5eb6d` |
| assets/hooks/pre-bash.sh | hook | `a551e12576fb` |
| assets/skill-packs/README.md | doc | `e52a3656dea1` |
| assets/skills/systematic-debugging/SKILL.md | skill | `d85aaea15f86` |
| assets/skills/test-driven-development/SKILL.md | skill | `375b8b3556ab` |
| assets/skills/verification-before-completion/SKILL.md | skill | `7e8c7cd39999` |
| assets/templates/CLAUDE.md.tmpl | template | `61d83cd741ba` |
| assets/templates/HARNESS.md.tmpl | template | `cd4414c690be` |
| assets/templates/adr-template.md.tmpl | template | `67f733003f15` |
| assets/templates/architecture.md.tmpl | template | `59ced5d04fff` |
| assets/templates/decisions.md.tmpl | template | `1019d5790337` |
| assets/templates/env.example.tmpl | template | `d3092e18fcfa` |
| assets/templates/fragments/backlog_A.txt | fragmento | `740fa0b674eb` |
| assets/templates/fragments/backlog_B.txt | fragmento | `86dabb7c7518` |
| assets/templates/fragments/compliance.txt | fragmento | `239799525c75` |
| assets/templates/fragments/eval_agent_line_B.txt | fragmento | `39d97bf49155` |
| assets/templates/fragments/eval_cmd_line_B.txt | fragmento | `780b8abcf2bc` |
| assets/templates/fragments/eval_workflow_A.txt | fragmento | `ca4dcf6b177a` |
| assets/templates/fragments/eval_workflow_B.txt | fragmento | `84244962c9a0` |
| assets/templates/gitignore.tmpl | template | `0d32e330e244` |
| assets/templates/mcp.json.example.tmpl | template | `452e9e4cd41a` |
