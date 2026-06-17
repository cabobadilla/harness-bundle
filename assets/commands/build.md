---
description: Implement the most recent spec (generator agent).
---

**Pre-step (recomendado para lógica no trivial):**
Si la tarea involucra business logic, parsing, cálculos o flujos con edge
cases — invoca el skill `test-driven-development` vía la herramienta `Skill`
ANTES de delegar al generator. Esto fuerza tests-first y reduce regresiones.
Para edits triviales, cambios de config o docs, salta este pre-step.

Invoca el subagente `generator` para implementar el spec en `memory/specs/`.

El generator debe:
- Trabajar feature por feature.
- Usar git para checkpoints.
- Auto-evaluarse contra el spec antes de declarar hecho (lee y aplica
  `.claude/skills/verification-before-completion/SKILL.md`).
- NO usar context resets ni decomposición en sprints (target Opus 4.5+).

$ARGUMENTS
