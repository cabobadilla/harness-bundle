# harness-bundle

A shell scaffolder that bootstraps a **Planner · Generator · Evaluator** harness on top of Claude Code for any new project. Inspired by [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) (Anthropic Labs, Mar 2026) and optimized for **Opus 4.5 or higher**.

> This repo is the **tool** that installs the harness. It is not itself a target project: you run `init-harness.sh` from here pointing at another directory, and the harness gets materialized over there.

---

## What the generated harness gives you

For each project you bootstrap:

```
my-project/
├── CLAUDE.md                 # project contract (persistent prompt)
├── .mcp.json                 # MCPs (empty initially; /config-stack populates it)
├── .claude/
│   ├── agents/               # planner.md, generator.md, evaluator-light.md
│   ├── commands/             # /plan, /config-stack, /build, /evaluate, /ship
│   ├── skills/               # TDD, systematic-debugging, verification (universal)
│   ├── hooks/                # on-stop, pre-bash, user-prompt-validator, ...
│   └── settings.json         # permissions + hooks
├── docs/                     # architecture.md + decisions/
└── memory/                   # specs/, backlog.md, decisions.md, evaluations/, sessions/
```

The **end-to-end flow** inside Claude Code:

```
/plan → /config-stack → /build → (/evaluate) → /ship
                          ↑          ↓
                          └──── memory/backlog.md
```

- **`/plan <goal>`** — the `planner` expands your prompt into a rich spec under `memory/specs/`, picks a high-level stack, and confirms the deploy target.
- **`/config-stack`** — challenges and confirms the stack (comparison table), copies applicable skill-packs, and declares MCPs in `.mcp.json` based on deploy+stack+git.
- **`/build`** — the `generator` implements the spec feature by feature and resolves items in `memory/backlog.md`.
- **`/evaluate`** — (optional, Level B) the `evaluator-light` reviews code and tests without a browser, persisting P0/P1/P2 findings to the backlog.
- **`/ship`** — verification gate → lint → tests → secret scan → commit → deploy (cloudflare/railway/vercel/none).

## Architecture levels

| Level | Agents | When to use |
|---|---|---|
| **A** (MVP) | Planner + Generator | Day-to-day work, tasks well within what Opus 4.5+ handles on its own. |
| **B** | + Light Evaluator (no browser) | Apps with business logic, edge cases, "it looks fine but I'm not sure it works". |
| **C** | + Full Evaluator with Playwright | Apps with UI, client deliverables. **Pending — see backlog in `CLAUDE.md`.** |

Rule of thumb: stay at A as long as you can; only move up when a real task shows you the current level isn't enough.

---

## Quick start

### 1. Make scripts executable

```bash
cd ~/CodeLab/harness-bundle
chmod +x *.sh
```

### 2. For each new project

```bash
./check-skills.sh                                   # BEFORE: audit ~/.claude/ (global plugins/skills)
./init-harness.sh ~/projects/my-new-app             # create scaffold (interactive)
./check-skills.sh                                   # AFTER: confirm nothing "lit up" by accident
cd ~/projects/my-new-app
claude                                              # open Claude Code
```

> To expose `check-skills` and `init-harness` as global commands, see `USER_GUIDE.md`.

Inside Claude Code:

```
/plan "a note-taking app with tags and search"
/config-stack
/build
```

That's it. The planner decides the stack — you don't pre-pick it.

### Non-interactive mode

```bash
HARNESS_PROJECT_NAME=my-app \
HARNESS_MISSION="Notes with tags" \
HARNESS_ARCH=B \
HARNESS_DEPLOY=railway \
init-harness --non-interactive ~/projects/my-app
```

Supported variables: `HARNESS_PROJECT_NAME`, `HARNESS_MISSION`, `HARNESS_PROJECT_TYPE` (`Estándar`|`Regulado`), `HARNESS_ARCH` (`A`|`B`), `HARNESS_GIT` (`yes`|`no`), `HARNESS_DEPLOY` (`none`|`cloudflare`|`railway`|`vercel`), `HARNESS_HOOK_*`.

---

## Bundle components

| Script | Purpose |
|---|---|
| `check-skills.sh` | Audits `~/.claude/` against §12 of the strategy. Read-only by default; `--suggest` prints commands, `--interactive` runs them with confirmation + backup. |
| `init-harness.sh` | Project bootstrap. Idempotent: re-running it doesn't destroy customizations. |
| `assets/` | Static content: agents, commands, hooks, skills, skill-packs, templates. The shell assembles; assets are the content. |

### Bundle stack

- **Bash 3.2** (macOS default, `/bin/bash`). No Bash 4+ features.
- POSIX userland: `sed`, `awk` (BSD), `grep`, `mkdir`, `cp`, `cat`, `head`, `mktemp`, `shasum -a 256`.
- No extra runtime (no Node, no Python, no `jq`).

---

## Repo structure

```
harness-bundle/
├── README.md              # this file
├── CLAUDE.md              # rules for working ON the bundle + backlog
├── USER_GUIDE.md          # step-by-step end-to-end guide
├── harness_strategy.md    # SOURCE OF TRUTH (Anthropic strategy v2.2)
├── MANIFEST.md            # inventory + asset checksums
├── VERSION                # bundle version (currently: 1i)
├── init-harness.sh        # scaffolder LOGIC
├── check-skills.sh        # ~/.claude/ audit
├── tests/                 # E2E (structural smoke + headless claude)
└── assets/
    ├── agents/            # planner, generator, evaluator-light
    ├── commands/          # plan, config-stack, build, evaluate, ship
    ├── hooks/             # on-stop, pre-bash, user-prompt-validator, ...
    ├── skills/            # universal: TDD, systematic-debugging, verification
    ├── skill-packs/       # stack-specific library (intentionally empty at start)
    └── templates/         # CLAUDE.md.tmpl, HARNESS.md.tmpl, fragments/
```

---

## How to work in this repo

Changes follow the **shell/content decoupling** rule:

| Change | Where |
|---|---|
| Text of an agent, command, or fragment | `assets/...` + update the checksum in `MANIFEST.md` (`shasum -a 256 <file> \| cut -c1-12`) |
| Flow, new question, bug fix | `init-harness.sh` + bump `VERSION` if the observable interface changes |
| Conceptual strategy | `harness_strategy.md` first, then the shell |

Mandatory local validation before declaring done:

```bash
./init-harness.sh /tmp/harness-test-$(date +%s)     # smoke
./tests/e2e-scaffold.sh                              # structural E2E (no API key required)
./tests/e2e-claude.sh                                # E2E with headless claude (requires ANTHROPIC_API_KEY)
```

Idempotency: running `init-harness.sh` twice against the same directory must skip what exists without breaking anything.

Non-negotiable conventions: conventional commits, `set -euo pipefail` stays in, Spanish-language user-facing messages, `MANIFEST` always in sync.

---

## References

- **`harness_strategy.md`** — source of truth: architecture, philosophy, implementation plan, configuration cleanup (§12), templates (§15).
- **`USER_GUIDE.md`** — step-by-step for end users of the bundle.
- **`CLAUDE.md`** — rules for working on this repo + prioritized backlog (P0-P3).
- **`MANIFEST.md`** — up-to-date asset inventory with checksums.

## Current status

- **Version:** v1i (see `VERSION`)
- **Supported levels:** A (MVP) and B (light evaluator without browser)
- **Pending:** Level C (evaluator + Playwright) and docs drift cleanup — see prioritized backlog in `CLAUDE.md`.
