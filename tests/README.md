# Tests del bundle

Dos scripts E2E. Exit 0 = pass; ambos imprimen el path del target preservado para inspección manual.

## `e2e-scaffold.sh` — smoke estructural (sin API key)

```bash
./tests/e2e-scaffold.sh
```

Verifica:
- Scaffolder no-interactivo (`--non-interactive`) corre sin error.
- 23 archivos esperados existen; 8 archivos no-seleccionados ausentes.
- `.mcp.json` y `.claude/settings.json` son JSON válido (Python `json.load`).
- Hooks seleccionados vs deselectados respetan flags.
- Git opcional: con `HARNESS_GIT=no`, el `settings.json` NO incluye permisos `Bash(git *)`.
- Idempotencia: 2ª corrida sobre el mismo dir muestra "ya existe" y no rompe.
- Variante `HARNESS_GIT=yes`: `.git` creado y permisos presentes.

Corre en ~2s. Sin costo. No requiere `ANTHROPIC_API_KEY`. **Es el test que se corre por default antes de commitear.**

## `e2e-claude.sh` — invoca Claude Code real (requiere API key)

```bash
export ANTHROPIC_API_KEY=sk-ant-...
./tests/e2e-claude.sh
```

Scaffoldea un dir temporal y ejecuta `claude -p` en modo headless con `/plan` y `/build`. Verifica que el harness produce código real, no solo archivos de configuración.

- **Costo:** ~$0.10-0.30 por corrida (Opus, 2 prompts cortos sobre una calculadora de propinas).
- **Sin API key:** skip con mensaje, exit 0 — no rompe CI.
- **Target preservado** para inspección al terminar (no se borra).
- **Logs:** `/tmp/e2e-claude-{scaffold,plan,build}.log`.

Cuándo correrlo:
1. Antes de publicar una versión nueva del bundle.
2. Después de cambios grandes a los prompts de los agentes.
3. Como gate en CI si querés cobertura E2E real (configurar `ANTHROPIC_API_KEY` como secret).

## Variables de entorno para `--non-interactive`

```
HARNESS_PROJECT_NAME           default: basename(target)
HARNESS_MISSION                default: "<COMPLETAR>"
HARNESS_PROJECT_TYPE           default: "Personal"
HARNESS_ARCH                   default: "B"        (A | B)
HARNESS_GIT                    default: "no"       (yes | no)
HARNESS_DEPLOY                 default: "none"     (none | cloudflare | railway | vercel | manual)
HARNESS_MCP_GITHUB             default: "no"       (yes | no)
HARNESS_MCP_POSTGRES           default: "no"       (yes | no)
HARNESS_HOOK_ON_STOP           default: "yes"      (yes | no)
HARNESS_HOOK_PRE_BASH          default: "yes"      (yes | no)
HARNESS_HOOK_USER_PROMPT_VALIDATOR  default: "yes" (yes | no)
HARNESS_HOOK_POST_EDIT_FORMAT  default: "no"       (yes | no)
HARNESS_HOOK_SESSION_START     default: "no"       (yes | no)
HARNESS_HOOK_SUBAGENT_STOP     default: "no"       (yes | no)
```
