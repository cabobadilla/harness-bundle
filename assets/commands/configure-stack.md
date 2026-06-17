---
description: Detecta el stack del spec actual y copia los skill-packs correspondientes desde el bundle a .claude/skills/ del proyecto. Idempotente.
---

Tu objetivo es **terminar de configurar el proyecto** después del `/plan`: identificar qué skill-packs del bundle aplican al stack que el planner decidió, y copiarlos localmente.

## Proceso

### 1. Identificar el stack
Lee, en orden:
- El último spec en `memory/specs/<slug>.md` (más reciente por fecha de modificación).
- La sección `## Stack` de `CLAUDE.md`.
- La sección `## Arquitectura sintética` de `CLAUDE.md` y `docs/architecture.md`.

Extraé los tags relevantes (ej: `react`, `vite`, `fastapi`, `tailwind`, `pydantic`, `postgres`). No inventes: solo lo que esté escrito.

### 2. Localizar la librería de skill-packs del bundle
La librería vive en `<bundle-dir>/assets/skill-packs/`. Para encontrarla:
- Si `init-harness` es global, `which init-harness` → seguir el symlink con `readlink` → tomar el dirname → `assets/skill-packs/`.
- Si no, preguntá al usuario el path del bundle.

### 3. Mapear tags → packs
Para cada tag identificado en el paso 1, buscá un subdirectorio en la librería cuyo nombre contenga ese tag (ej: `react` → `react-component-pattern/`). Lista todos los packs candidatos.

Si la librería está **vacía** (caso default del bundle nuevo), informá al usuario:
```
La librería <bundle>/assets/skill-packs/ está vacía.
No hay packs para copiar todavía — el bundle arranca vacío a propósito.
Podés:
  (a) Continuar sin packs específicos (los 3 universales ya están copiados).
  (b) Crear un pack en <bundle>/assets/skill-packs/<nombre>/SKILL.md y re-correr este command.
  (c) Si ya tenés el skill en ~/.claude/skills/<nombre>/, te lo copio local: ¿lo hago?
```

### 4. Para cada pack candidato

Verificá presencia en este orden:
1. **Bundle library** (`<bundle>/assets/skill-packs/<nombre>/SKILL.md`) → copiar a `.claude/skills/<nombre>/SKILL.md`.
2. **Global del usuario** (`~/.claude/skills/<nombre>/SKILL.md`) → copiar local para portabilidad.
3. **No existe en ningún lado** → reportar el missing y ofrecer al usuario:
   - **(s)kip**: continuar sin este pack. Listalo en `memory/decisions.md` como deuda.
   - **(t)stub**: crear un boilerplate vacío en `.claude/skills/<nombre>/SKILL.md` para que el usuario lo complete después.
   - **(a)abort**: parar, mostrar las instrucciones de creación, y pedir al usuario re-correr `/configure-stack` cuando esté listo.

### 5. Idempotencia
Si un skill ya existe en `.claude/skills/<nombre>/SKILL.md`, NO lo sobreescribas. Reporta `(ya existía, OK)` y seguí con el siguiente.

### 6. Reporte final
Output estructurado:
```
Stack detectado: [react, vite, fastapi]
Packs aplicados:
  ✓ react-component-pattern   (desde bundle)
  ✓ fastapi-endpoint           (desde global ~/.claude/skills/)
  ⚠ tailwind-design            (no existe — skipped, anotado en decisions.md)

Estado actual de .claude/skills/:
  <output de `ls .claude/skills/`>

Próximo paso: /build
(El generator descubrirá automáticamente los skills nuevos — no hace falta
editar agents/generator.md ni CLAUDE.md.)
```

Anotá los skips en `memory/decisions.md` con fecha, para no perder visibilidad.

## Restricciones

- NO modifiques los skills universales en `.claude/skills/{systematic-debugging,test-driven-development,verification-before-completion}/`.
- NO copies más de un pack por tag (si hay dos matches, preguntá al usuario cuál querés).
- NO inventes packs que no existen. Si la librería está vacía, decílo claro y dejá que el usuario decida.

$ARGUMENTS
