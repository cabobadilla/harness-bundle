# Skill packs — librería del bundle (vacía al inicio)

Esta carpeta es la **fuente preferida** del comando `/configure-stack` para encontrar skills específicos del stack que el planner decidió.

Arranca **vacía a propósito**. La carga es responsabilidad del que usa el bundle, cuando un caso real lo justifique.

## Estructura esperada

Un subdirectorio por skill, igual que `assets/skills/`:

```
skill-packs/
├── react-component-pattern/
│   └── SKILL.md
├── fastapi-endpoint/
│   └── SKILL.md
├── tailwind-design/
│   └── SKILL.md
└── ...
```

Cada `SKILL.md` debe tener el frontmatter estándar:

```markdown
---
name: <nombre del skill>
description: <una línea — Claude la usa para decidir cuándo aplicar el skill>
---

# <Título>

<Procedimiento, anti-patrones, ejemplos>
```

## Cuándo agregar un pack acá

Cuando, después de un `/plan`, te das cuenta que el generator se beneficiaría de un procedimiento estable (no improvisado). Ejemplos:

- "Cada vez que agrego un endpoint FastAPI repito la misma estructura" → `fastapi-endpoint`.
- "Mis componentes React siempre necesitan props tipados + test + story" → `react-component-pattern`.
- "Los modelos Pydantic tienen un patrón de validación que aprendí caro" → `pydantic-validation`.

Si lo escribís una sola vez bien, el generator lo aplica consistentemente en todos los proyectos.

## Lo que NO va acá

- Skills universales (TDD, debugging, verification) — ya están en `assets/skills/` y se copian SIEMPRE.
- Skills experimentales sin validar — escribilos primero en un proyecto real, refinalos, y cuando estén estables movelos acá.
- Procedimientos triviales que cabe en una línea del CLAUDE.md del proyecto.

## Cómo los usa `/configure-stack`

1. Detecta el stack en el último spec o en CLAUDE.md.
2. Busca packs relevantes en este directorio.
3. Copia los matches a `.claude/skills/` del proyecto.
4. Si necesita un pack que no está acá → busca en `~/.claude/skills/` del usuario.
5. Si tampoco está → reporta qué falta y te ofrece opciones (skip / stub / abort).
