---
description: Pre-commit verification + conventional commit (no push).
---

Ejecuta en orden. Detente al primer fallo.

**Paso 0 — Verification gate (OBLIGATORIO):**
Invoca el skill `verification-before-completion` vía la herramienta `Skill`.
El skill define la compuerta de evidencia (tests, lint, hygiene, behavior, scope).
Si CUALQUIER chequeo del skill falla, ABORTA `/ship` y reporta qué falta.
No prosigas a los pasos 1-7 hasta que el skill apruebe con evidencia.

1. Run linter (auto-detect: `npm run lint` o `ruff check .`).
2. Run tests (auto-detect: `npm test`, `pytest`).
3. Secret scan: `grep -rE '(api[_-]?key|secret|token|password)\s*=' --include='*.{ts,js,py}' .`
4. Show `git diff --stat`.
5. Pide al usuario confirmación.
6. Construye un mensaje de conventional commit basado en el diff.
7. `git commit` (NO push).
