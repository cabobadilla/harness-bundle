# Guía de usuario — harness-bundle

**Versión:** v1f · **Target:** Claude Code con Opus 4.5+ · **OS:** macOS / Linux

Este bundle entrega cuatro scripts independientes:

| Script | Para qué |
|---|---|
| **`check-skills.sh`** | Audita tu `~/.claude/` (skills, plugins, settings) **antes** y **después** del bootstrap. |
| **`init-harness.sh`** | Crea el scaffold del proyecto (arquitectura Planner · Generator · Evaluator). |
| **`install-global.sh`** | Opcional: expone `check-skills` y `init-harness` como comandos globales (symlinks en `~/.local/bin`). |
| **`uninstall-global.sh`** | Revierte la instalación global. |

> Regla de oro: corré `check-skills` antes Y después del scaffolding. El segundo run es tu red de seguridad.

## TL;DR — flujo completo

```bash
# Una sola vez: hacer scripts ejecutables + (opcional) instalar global
cd ~/CodeLab/harness-bundle
chmod +x *.sh
./install-global.sh                       # opcional pero recomendado

# Por cada proyecto nuevo:
check-skills                              # ANTES — auditar entorno
init-harness ~/proyectos/mi-app-nueva     # crear scaffold (NO pide stack — lo decide el planner)
check-skills                              # DESPUÉS — confirmar limpieza
cd ~/proyectos/mi-app-nueva
claude                                    # abrir Claude Code
# Dentro de Claude Code:
#   /plan "<tu objetivo en 1-4 frases>"   ← planner decide stack
#   /configure-stack                       ← copia skill-packs del stack
#   /build                                 ← generator implementa
```

> Si no instalaste global, reemplazá `check-skills` por `./check-skills.sh` y `init-harness` por `./init-harness.sh` (desde el dir del bundle).

---

## Paso 0 — Requisitos
- macOS o Linux con `bash` 3.2+, `awk`, `sed`, `grep`, `shasum`.
- Claude Code instalado (`claude --version` debe responder).
- Permisos de escritura en el directorio donde vas a crear tu proyecto.

```bash
cd /ruta/donde/tengas/harness-bundle
chmod +x init-harness.sh check-skills.sh install-global.sh uninstall-global.sh   # solo 1ª vez
```

### Opcional — comandos globales (`check-skills` y `init-harness`)
Si usás el bundle seguido, conviene tener ambos comandos en PATH:

```bash
./install-global.sh                          # ambos en ~/.local/bin
./install-global.sh --only check-skills      # solo el auditor
./install-global.sh --only init-harness      # solo el scaffolder
./install-global.sh --dest /usr/local/bin    # otro dir (puede requerir sudo)
```

Después, desde **cualquier** directorio (sin `.sh`, sin `./`):
```bash
check-skills                          # auditar entorno
check-skills --suggest                # ver comandos sugeridos
check-skills --interactive            # ejecutar con confirmación

init-harness ~/proyectos/mi-app       # scaffold de un proyecto nuevo
```

Para revertir: `./uninstall-global.sh` (con `--only` para uno solo).
Solo borra si el target es un symlink creado por este install — nunca pisa archivos del usuario.

Si `~/.local/bin` no está en tu PATH, el install te muestra qué línea agregar a `~/.zshrc`.

---

## Paso 1 — Auditar tu entorno ANTES (pre-flight)

```bash
check-skills                          # si instalaste global (desde cualquier dir)
# o
./check-skills.sh                     # desde el dir del bundle
```

**Qué hace:** lee `~/.claude/skills/`, `~/.claude/plugins/installed_plugins.json` y `~/.claude/settings.json`, y los cruza contra la tabla de auditoría de §12 del `harness_strategy.md`. **No modifica nada.**

**Qué vas a ver:**
- ✓ verde — `KEEP` (alineado con el harness).
- ⚠ amarillo — `DEFER` o "revisión manual".
- ✗ rojo — `DROP` (incompatible con el harness; el agente principal puede contradecir al CLAUDE.md del proyecto).

**Si aparecen DROPs o DEFERs:**
```bash
check-skills --suggest        # imprime los comandos sin ejecutarlos
check-skills --interactive    # ejecuta solo con tu confirmación uno a uno
```
El modo `--interactive` hace **backup automático** de `~/.claude/settings.json` antes de tocar nada.

**Criterio de "listo para Paso 2":** salida termina con `✓ Entorno alineado con el harness. Sin acciones requeridas.` — o vos decidiste conscientemente convivir con los DEFERs.

---

## Paso 2 — Crear el scaffold del proyecto

```bash
init-harness /ruta/de/tu/proyecto-nuevo          # si instalaste global
# o
./init-harness.sh /ruta/de/tu/proyecto-nuevo     # desde el dir del bundle
```

(También podés correrlo sin argumento — te pregunta el directorio.)

**El script te pregunta:**

| Pregunta | Opciones | Cuándo elegir cuál |
|---|---|---|
| Nombre del proyecto | texto libre | Default = basename del directorio. |
| **Misión** | **1-2 frases — qué hace, para quién** | **El planner usa esto como contexto inicial. Invertir 30 segundos acá vale mucho.** |
| Tipo de proyecto | Personal / Enterprise / Regulado | "Regulado" agrega sección de compliance y deniega paths con datos sensibles. |
| Arquitectura | **A** (planner+generator) / **B** (+ evaluator ligero) | Empezá en **A**. Subí a **B** cuando una tarea real te muestre que el generator solo no basta. |
| MCP github / postgres | sí/no | Habilitalos si vas a usar issues/PRs o DBs locales. |
| Hooks | sí/no | "Sí" recomendado: bloquea `rm -rf`, evita commits durante `/freeze`. |

**Lo que NO te pregunta:**
- **Stack**: ya no se pregunta al inicio. El planner lo decide en `/plan` (alto nivel) y se afina con `/configure-stack`. Alinea con la regla de oro de §7.1 de la estrategia: *"Constrain the deliverables, let the generator figure out the path."*
- **Tipo de solución / scaffold pre-armado**: el bundle ya no entrega scaffolds (Flask, etc.). El esqueleto es 100% agnóstico del stack. Si querés Flask, el planner lo decide en `/plan` y el generator escribe `app.py` en `/build` — el flujo correcto del harness.
- **Copia de los 3 skills universales** (`systematic-debugging`, `test-driven-development`, `verification-before-completion`): **siempre se copian** al `.claude/skills/`. Los agents y commands los referencian por path, así que el proyecto es portable.

**Lo que vas a tener al terminar:**
```
mi-proyecto/
├── CLAUDE.md                      ← contrato del proyecto (editar <COMPLETAR>)
├── HARNESS.md                     ← referencia rápida del harness
├── .mcp.json                      ← MCPs activos
├── .mcp.json.example              ← plantilla con más MCPs
├── .claude/
│   ├── settings.json              ← permisos + hooks
│   ├── agents/                    ← planner.md, generator.md, (evaluator.md)
│   ├── commands/                  ← plan, build, ship, freeze, unfreeze, (evaluate)
│   ├── skills/                    ← 3 skills referenciados por agents/commands
│   └── hooks/                     ← pre-bash, on-stop, freeze-guard
├── docs/
│   ├── architecture.md
│   └── decisions/0000-template.md
├── memory/
│   ├── decisions.md
│   ├── specs/                     ← acá guarda specs el planner
│   └── sessions/                  ← logs de stop hook
└── .gitignore, .env.example, .git/
```

**Idempotencia:** podés correr el script 2x sobre el mismo directorio. Lo que ya existe se omite (`⚠ ... ya existe — se omite`); no destruye customizaciones.

---

## Paso 3 — Auditar tu entorno DESPUÉS (post-flight)

```bash
check-skills                          # o ./check-skills.sh desde el bundle
```

Mismo comando que el Paso 1. **¿Por qué dos veces?** Algunas operaciones (instalar un plugin, aceptar un skill desde una página) pueden agregar entradas a `~/.claude/` sin que te des cuenta. Una corrida rápida confirma que tu entorno sigue limpio.

**Criterio de "listo para usar el harness":** salida idéntica (o más limpia) que el Paso 1.

---

## Paso 4 — Primer uso del harness

```bash
cd /ruta/de/tu/proyecto-nuevo
# Completa los <COMPLETAR> en CLAUDE.md
cp .env.example .env                # y agregá tus credenciales
claude                              # abre Claude Code
```

Dentro de Claude Code, el ciclo básico es:

| Slash command | Qué hace | Cuándo usarlo |
|---|---|---|
| `/plan "<objetivo en 1-4 frases>"` | Invoca al **planner**: expande el objetivo a un spec rico en `memory/specs/`, decide el stack alto nivel y actualiza `CLAUDE.md` + `docs/architecture.md`. | Al inicio de un build no trivial. |
| `/configure-stack` | Detecta el stack del spec y copia los skill-packs correspondientes desde la librería del bundle a `.claude/skills/`. Idempotente. Si falta algún pack te ofrece skip / stub / abort. | Inmediatamente después de `/plan` y antes de `/build`. |
| `/build` | Invoca al **generator**: implementa el spec más reciente feature por feature, con auto-evaluación. | Cuando aprobaste el spec y configuraste los skills. |
| `/evaluate` *(solo Arquitectura B)* | Invoca al **evaluator ligero**: revisa código y output contra el spec, sin browser. | Antes de cerrar entregables o features con edge cases. |
| `/freeze <path>` / `/unfreeze` | Restringe / libera el scope de edición durante el trabajo. | Cuando querés evitar tocar zonas frágiles. |
| `/ship` | Verification gate (skill `verification-before-completion`) + lint + tests + secret scan + conventional commit (NO push). | Antes de cada commit significativo. |

### Sobre `/configure-stack` y los skill-packs

El bundle entrega una **librería de skill-packs vacía a propósito** (`assets/skill-packs/`). Esto es de diseño: definir qué skills necesita "React+Vite" o "FastAPI" es una decisión técnica que no se puede automatizar bien sin contexto real.

**Cuándo aparecen packs:** los creás vos cuando, después de hacer un proyecto, te das cuenta que repetiste un procedimiento. Ej:
- "Cada endpoint FastAPI tiene la misma estructura" → escribís `assets/skill-packs/fastapi-endpoint/SKILL.md`.
- "Mis componentes React siempre necesitan props tipados + test" → `react-component-pattern`.

**Qué hace `/configure-stack` si la librería está vacía** (caso default del bundle nuevo):
1. Te informa que no hay packs específicos disponibles.
2. Los 3 universales (TDD, debugging, verification) ya están copiados — el proyecto es funcional.
3. Te ofrece copiar algún skill global tuyo (`~/.claude/skills/<nombre>`) si te aplica.
4. Listo. Seguís con `/build`.

**Qué hace si un pack solicitado NO existe en ningún lado:**
1. Te lista qué falta exactamente.
2. Te da 3 opciones:
   - **skip**: continuar sin ese pack (lo anota en `memory/decisions.md` como deuda).
   - **stub**: crear un boilerplate vacío en `.claude/skills/<nombre>/SKILL.md` para que lo completes después.
   - **abort**: parar; vos lo creás manualmente; re-corrés `/configure-stack`.

---

## Mantenimiento

- **Editar el contenido del harness (un agente, un command):** modificá el archivo bajo `harness-bundle/assets/` y actualizá su checksum en `MANIFEST.md`. No tocás la shell.
- **Editar el flujo del scaffolder:** modificá `init-harness.sh`. Subí `VERSION` cuando cambia algo observable.
- **Volver a auditar tu entorno periódicamente:** corré `check-skills` cuando agregués/quités plugins en Claude Code.
- **Si moviste el bundle de directorio** después de instalar global: los symlinks quedaron rotos. Re-ejecutá:
  ```bash
  ./uninstall-global.sh && ./install-global.sh
  ```
  Idempotente: si los symlinks ya apuntan al nuevo path, no hace nada.

---

## Troubleshooting

| Síntoma | Probable causa | Acción |
|---|---|---|
| `awk: newline in string ...` | Estás en una versión vieja del bundle (≤ v1d). | Actualizá a v1e o superior (este bundle). |
| `HARNESS.md` no se creó | Mismo bug que arriba. | Idem. |
| `.mcp.json` o `settings.json` se "regeneraron" tras re-correr | Estás en ≤ v1d. | Idem. |
| El agente no usa los skills | Verificá que `.claude/skills/` tenga los 3 SKILL.md y que `CLAUDE.md` tenga la sección "Skills requeridos". | Re-correr `init-harness` (es idempotente). |
| `check-skills` reporta plugins que ya no usás | El usuario nunca corrió la desinstalación. | `check-skills --interactive`. |
| `claude plugin uninstall` falla | El plugin podría ser de marketplace privado. | Desinstalar manualmente desde la UI de Claude Code. |
| `command not found: check-skills.sh` | El comando global se llama `check-skills` (sin `.sh`). | Usá `check-skills`. El `.sh` solo aplica corriendo desde el bundle con `./`. |
| `./check-skills.sh: No such file or directory` | Estás en un dir que no es el bundle. | Movete al bundle: `cd ~/CodeLab/harness-bundle`. O usá el global: `check-skills`. |
| `init-harness` falla con "Falta assets/" | Moviste el bundle después de instalar global, los symlinks quedaron rotos. | `cd <bundle-nuevo> && ./uninstall-global.sh && ./install-global.sh`. |
| El target del symlink existe pero es otro archivo | Ya tenías un script con el mismo nombre en `~/.local/bin`. | `install-global.sh` no sobreescribe. Renombrá tu script o `rm` el antiguo manualmente. |

---

## Referencias
- `harness_strategy.md` — la estrategia completa (§12 = auditoría de plugins).
- `CLAUDE.md` (este repo) — reglas para trabajar sobre el bundle mismo.
- `MANIFEST.md` — inventario versionado de assets.
