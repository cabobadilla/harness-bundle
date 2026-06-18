---
description: Implement the latest spec + resolve backlog findings (generator agent).
---

## Inputs que el generator debe leer
1. **Spec más reciente** en `memory/specs/<slug>.md`.
2. **Backlog** en `memory/backlog.md` (si existe — son findings de `/evaluate` o TODOs pendientes que el generator debe resolver además de implementar el spec).
3. **Convenciones** en `CLAUDE.md`.

## Pre-step (recomendado para lógica no trivial)
Si la tarea involucra business logic, parsing, cálculos o flujos con edge
cases — invoca el skill `test-driven-development` vía la herramienta `Skill`
ANTES de delegar al generator. Esto fuerza tests-first y reduce regresiones.
Para edits triviales, cambios de config o docs, salta este pre-step.

## Delegación
Invoca el subagente `generator` para:
- Implementar el spec en `memory/specs/`.
- Resolver los ítems pendientes (`- [ ]`) de `memory/backlog.md` y marcarlos
  `- [x]` cuando estén hechos.
- Trabajar feature por feature.
- Aplicar las convenciones del repo (.venv para Python, responsive para web,
  conventional commits).
- Usar git para checkpoints (si hay repo git).
- Auto-evaluarse contra el spec antes de declarar hecho (skill
  `verification-before-completion`).

## Restricciones
- NO context resets ni decomposición en sprints (target Opus 4.5+).
- NO sobreescribir el spec — si el spec cambia, llamar a `/plan` primero.

$ARGUMENTS
