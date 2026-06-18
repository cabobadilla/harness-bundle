---
description: Reta y confirma el stack con el usuario (tabla comparativa), copia skill-packs aplicables, e instala los MCPs necesarios.
---

Tu objetivo es **confirmar el stack con el usuario antes de cementarlo**, luego copiar skill-packs **y declarar los MCPs apropiados en `.mcp.json`**. Nunca asumas — siempre presenta la tabla, espera respuesta del usuario, y solo entonces actúas.

## Token economy
- Antes de leer todo: `ls memory/specs/` y `grep -i "stack\|deploy" CLAUDE.md` para ubicarte.
- Lee el spec más reciente (un solo Read).
- NO hagas WebSearch sin pedir permiso al usuario.

## Proceso

### 1. Lee lo que ya hay
- Último archivo en `memory/specs/<slug>.md` (por fecha de mod).
- Sección `## Stack` y `## Deployment` de `CLAUDE.md`.
- `docs/architecture.md` solo si el spec no menciona stack.

Extrae:
- **Frontend** (si aplica): framework + estilos.
- **Backend** (si aplica): runtime + framework + ORM.
- **Datos**: tipo de DB / storage.
- **Deploy target**: ya elegido en init (`cloudflare` / `railway` / `vercel` / `none` / `manual`).

### 2. Presenta la tabla comparativa y RETA al usuario

Para cada dimensión donde el planner dejó una opción, muestra una tabla así (ajusta filas al dominio real del spec):

```
| Opción           | Complejidad | Pros                                     | Contras                       | Encaja con deploy actual? |
|------------------|-------------|------------------------------------------|-------------------------------|---------------------------|
| React + Vite     | Media       | Ecosistema enorme, SPA rápida            | Bundle grande, build step     | ✅ Cloudflare Pages       |
| HTMX + Jinja     | Baja        | Simple, server-rendered, 0 build         | Menos ecosistema UI           | ✅ Cualquiera             |
| Next.js          | Media-Alta  | SSR, image optim, full-stack             | Lock-in suave a Vercel        | ✅ Vercel · ⚠️ otros      |
```

Después de la tabla, pregunta literalmente:

> **Antes de seguir necesito que confirmes el stack:**
> 1. ¿La opción del planner (`<X>`) sigue siendo la que querés?
> 2. ¿Hay restricciones (talento del equipo, deploy target, performance) que no consideré?
> 3. Si no es la mejor, ¿cuál de la tabla?
>
> Respondé con: **"confirmo"** / **"cambio a <opción>"** / **"explicame X con más detalle"**.

**No avances al paso 3 hasta tener respuesta explícita del usuario.** Si pide más detalle, explicá esa fila con un párrafo corto y volvé a preguntar.

### 3. Persistir la decisión

Cuando el usuario confirme:
- Actualizá la sección `## Stack` de `CLAUDE.md` con el stack final.
- Appendeá una línea a `memory/decisions.md`:
  `YYYY-MM-DD — Stack confirmado: <X>. Razón: <una frase>.`
- Si el stack confirmado choca con el `DEPLOY_TARGET` actual, **alertá al usuario** y pedile que decida: cambiar stack o cambiar deploy.

### 4. Copiar skill-packs del stack confirmado

Extraé tags del stack final (`react`, `vite`, `fastapi`, `tailwind`, `postgres`, etc.).

Para cada tag, en este orden:
1. Bundle library (`<bundle>/assets/skill-packs/<nombre>/SKILL.md`) → copiar a `.claude/skills/<nombre>/SKILL.md`.
2. Global (`~/.claude/skills/<nombre>/SKILL.md`) → copiar local para portabilidad.
3. No existe → reportar y ofrecer **(s)kip / (t)stub / (a)abort**. El skip queda anotado en `memory/decisions.md`.

Si la librería del bundle está vacía y nada matchea global: avisa que arranca sin packs específicos, los 3 universales bastan para empezar.

### 5. Declarar MCPs en `.mcp.json`

Leé `.mcp.json` (debería existir vacío: `{"mcpServers": {}}`). Tu trabajo es proponer al usuario qué MCPs declarar según:
- **Deploy target** (de la sección `## Deployment` de CLAUDE.md): `cloudflare` / `railway` / `vercel` / `none`
- **Stack confirmado**: si menciona postgres/supabase, sugerí el MCP correspondiente
- **Git inicializado**: si `.git/` existe, sugerí MCP de GitHub

Presenta una lista con check `[x]` (recomendado) o `[ ]` (opcional). Ejemplo:

```
MCPs sugeridos según tu setup (deploy=cloudflare, stack=react+postgres, git=yes):
  [x] cloudflare-bindings   (deploy target)
  [x] postgres              (DB del stack)
  [ ] github                (opcional — para crear PRs/issues desde Claude)

Confirmá con "ok" o ajustá: "+github" / "-postgres".
```

**No avances hasta tener confirmación del usuario.** Una vez confirmado, modificá `.mcp.json` (preservando entradas existentes). Snippets canónicos:

```json
"cloudflare-bindings": {
  "command": "npx",
  "args": ["-y", "mcp-remote", "https://bindings.mcp.cloudflare.com/sse"]
}
```
```json
"railway": {
  "command": "npx",
  "args": ["-y", "mcp-remote", "https://mcp.railway.com"]
}
```
```json
"vercel": {
  "command": "npx",
  "args": ["-y", "mcp-remote", "https://mcp.vercel.com"]
}
```
```json
"github": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-github"],
  "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}" }
}
```
```json
"postgres": {
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-postgres"],
  "env": { "DATABASE_URL": "${DATABASE_URL}" }
}
```

Si un MCP usa env vars (`GITHUB_TOKEN`, `DATABASE_URL`), recordá al usuario agregarlas a `.env`.

### 6. Idempotencia
- `.claude/skills/<nombre>/SKILL.md` ya existe → NO sobreescribir. Reportá `(ya existía, OK)`.
- Entrada MCP ya existe en `.mcp.json` → preservar la existente, no duplicar.

### 7. Reporte final

```
Stack confirmado: <X>
Deploy target:    <cloudflare|railway|vercel|none>
Packs aplicados:
  ✓ react-component-pattern   (desde bundle)
  ⚠ tailwind-design            (missing — skipped, anotado en decisions.md)
MCPs declarados en .mcp.json:
  ✓ cloudflare-bindings
  ✓ postgres                  (recordá poblar DATABASE_URL en .env)

Estado actual de .claude/skills/:
  <output de `ls .claude/skills/`>

Próximo paso: /build
```

## Restricciones
- NO modificar los 3 skills universales (`systematic-debugging`, `test-driven-development`, `verification-before-completion`).
- NO copiar más de un pack por tag (si hay dos, preguntá cuál).
- NO inventar packs que no existen.
- NO usar WebSearch sin permiso explícito.

$ARGUMENTS
