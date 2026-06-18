---
description: Verification gate → tests → commit → deploy según target configurado.
---

Ejecuta en orden. Detente al primer fallo. Cada paso reporta resultado antes de pasar al siguiente.

## Paso 0 — Verification gate (OBLIGATORIO)
Invoca el skill `verification-before-completion` vía la herramienta `Skill`.
Si CUALQUIER chequeo del skill falla, ABORTA `/ship` y reportá qué falta.
No prosigas hasta que el skill apruebe con evidencia.

## Paso 1 — Lint
Auto-detect del stack:
- Python con `.venv`: `source .venv/bin/activate && (ruff check . 2>/dev/null || flake8 . 2>/dev/null || pylint **/*.py 2>/dev/null)`
- JS/TS: `npm run lint` si el script existe.
- Si no hay linter configurado: reportar y continuar (no abortar).

## Paso 2 — Tests
- Python: `source .venv/bin/activate && pytest`
- JS/TS: `npm test`
- Si no hay tests: reportar como warning, no abortar. Si hay y fallan: abortar.

## Paso 3 — Secret scan
```
grep -rEn '(api[_-]?key|secret|token|password|bearer)\s*=\s*["'\''][^"'\'']{8,}' \
  --include='*.{ts,js,py,go,rs,java,rb,php}' --exclude-dir=node_modules --exclude-dir=.venv .
```
Cualquier match → mostrar al usuario y abortar hasta que confirme.

## Paso 4 — Diff
Mostrar `git diff --stat` y `git status`. Si no hay cambios staged: stopear con
mensaje claro.

## Paso 5 — Commit
- Pedir confirmación al usuario para proceder con el commit.
- Construir un mensaje de **conventional commit** basado en el diff (ej: `feat: add tag filter to notes list`, `fix: handle empty form submit`).
- `git commit` (NO push aún).

## Paso 6 — Deploy según `DEPLOY_TARGET`

Leer `## Deployment` de `CLAUDE.md`. Confirmar al usuario antes de cualquier deploy:
> Voy a desplegar a **<target>**. Confirmá con "deploy" o cancela con "no".

Según target:

### `cloudflare`
1. Verificar `wrangler` instalado: `wrangler --version` (si no, instruir
   `npm install -g wrangler` y abortar).
2. Confirmar que existe `wrangler.toml` o `wrangler.jsonc` en el repo.
3. `wrangler deploy` (o `wrangler pages deploy <dir>` si es Pages).
4. Reportar la URL del deploy.

### `railway`
1. Verificar `railway` CLI: `railway --version`.
2. `railway up --detach` (o el comando que el repo documente).
3. Reportar URL del servicio.

### `vercel`
1. Verificar `vercel` CLI: `vercel --version`.
2. `vercel --prod` (o `vercel deploy --prod`).
3. Reportar URL del deploy.

### `manual`
Imprimir el checklist que el repo definió en `docs/deploy.md` (si existe) o
generar uno basado en el stack. NO ejecutar nada.

### `none`
Saltar el paso. Avisar: "Deploy target = none. Commit hecho, no se hace deploy."

## Paso 7 — Push (opcional)
Preguntar al usuario si quiere `git push` también (si hay git).
NUNCA `git push --force` sin pedirlo explícitamente.

## Reporte final
- ✅ / ❌ por cada paso.
- URL del deploy (si aplica).
- Próximos pasos sugeridos.
