---
description: Lightweight QA — review code/output against spec, persist findings as backlog for /build.
---

Invoca el subagente `evaluator` para revisar lo recién construido.

Este es el evaluator LIGERO: lee código y output, NO lanza browser. Útil como
segunda opinión antes de `/ship`. Para QA completa con browser real, ver el
backlog del Nivel C (Playwright) en HARNESS.md.

## Lo que el evaluator hace
- Lee diff (`git diff`) y archivos relevantes (no ejecuta la app, no Playwright).
- Verifica contra el spec en `memory/specs/` y las convenciones en `CLAUDE.md`
  (incluyendo `.venv` para Python y responsive para web).
- Corre la suite de tests existente y reporta pass/fail.
- Gradúa: spec coverage, correctness, code quality, gaps — verdict claro en cada uno.
- Escribe reporte completo a `memory/evaluations/<slug>-<date>.md`.
- **Genera backlog accionable en `memory/backlog.md`** (append) con findings
  priorizados P0/P1/P2 que `/build` consumirá automáticamente en la próxima
  iteración.
- Es escéptico: encuentra gaps, no firma de complacencia.

## Loop esperado
```
/plan → /config-stack → /build → /evaluate
                          ↑          ↓
                          └──── memory/backlog.md (findings → next /build)
                                                       ↓
                                                     /ship
```

$ARGUMENTS
