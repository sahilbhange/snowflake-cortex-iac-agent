# CoCo CLI Skill & Agent Setup Guide

How to build, structure, and install native Cortex Code CLI skills and agents.
Covers everything needed to build what's in this repo from scratch.

---

## Core Concepts

### CoCo CLI Runtime

CoCo CLI supports multiple LLM backends. At launch it defaulted to Claude (Anthropic) models
only (`opus`, `sonnet`, `haiku`), but newer versions also support OpenAI models (e.g., GPT-5.2)
via `/model`. The Snowflake Cortex LLM catalog (llama4-maverick, deepseek-r1, etc.) is
available for server-side workloads (SQL `SNOWFLAKE.CORTEX.COMPLETE()`, Cortex Agents,
Cortex Analyst) but not for the CoCo coding agent itself.

Key points:
- `CLAUDE.md` is the Claude-specific project instruction file — auto-loaded in Claude sessions only
- There is no model-agnostic equivalent of `CLAUDE.md` (no `CORTEX.md` or `COCO.md` convention)
- `.cortex/skills/` and `.cortex/agents/` with `SKILL.md` files are the **model-agnostic** way
  to deliver project context — these load regardless of which LLM backend is active
- A root-level `SKILL.md` in the repo may not be recognized by all model backends; always place
  skills inside `.cortex/skills/<name>/SKILL.md`

### Model-Agnostic Skill Design

When building skills that work across CoCo model backends (Claude, GPT, future models):

**Problem:** `CLAUDE.md` only loads in Claude sessions. If you switch models, any domain rules
(naming conventions, provider constraints, NEVER/ALWAYS guardrails) defined exclusively in
`CLAUDE.md` are invisible to the non-Claude session.

**Solution:** Embed domain rules directly in the router skill's `SKILL.md`.

```
.cortex/skills/coco-iac-agent/SKILL.md    ← contains domain rules + routing table
CLAUDE.md                                  ← optional, keeps rules "always on" for Claude sessions
```

**Design principles:**
- **Primary source of truth:** `.cortex/skills/<router>/SKILL.md` — loaded by all models when the skill is invoked
- **`CLAUDE.md` as a safety net:** Keep it for Claude sessions where users may ask questions
  without invoking the skill. It's redundant when the skill is active, but catches ad-hoc conversations.
- **Root `SKILL.md` is not portable:** A `SKILL.md` at the repo root may only be recognized by
  Claude-based sessions. Always place the canonical copy in `.cortex/skills/`.
- **External skill copies drift:** Avoid copying skills to `~/cortex-skills/` or
  `~/.snowflake/cortex/skills/`. Use symlinks if global access is needed, or rely on
  project-level `.cortex/` exclusively.
- **Prompt style:** Write instructions in plain, imperative English. Avoid Claude-specific
  prompt patterns (XML tags, `<instructions>` blocks) — they may not transfer to other models.
  Markdown headings, bullet lists, and tables work universally.

### Skills vs Agents

| | Skill | Agent |
|---|---|---|
| What it does | Injects domain knowledge and instructions into the conversation | Executes tasks autonomously with its own context |
| Who runs commands | You (CoCo generates the commands) | The agent (runs commands itself) |
| Best for | Generating config changes, explaining plans, focused single operations | Multi-step workflows like running 10 plans, sequential stack walkthroughs |
| Autonomy | None — conversational | Autonomous (runs without asking) or non-autonomous (pauses for confirmation) |

**Rule of thumb:** If you'd be manually running multiple commands and reporting back, that's an agent. If you're asking CoCo to generate something for you to run, that's a skill.

---

## Directory Structure

CoCo looks for skills and agents at these locations (highest to lowest priority):

| Scope | Path |
|---|---|
| Project | `.cortex/skills/` or `.cortex/agents/` |
| User | `~/.snowflake/cortex/skills/` or `~/.snowflake/cortex/agents/` |
| Remote | Cloned from git via `/skill add <url>` |

**Project-level** (`.cortex/`) is checked into the repo — every teammate gets the skills automatically when they clone.

Each skill or agent is a **directory** named after the skill, containing `SKILL.md`:

```
.cortex/
├── skills/
│   └── <skill-name>/
│       └── SKILL.md
└── agents/
    └── <agent-name>/
        └── SKILL.md
```

The directory name becomes the `$invocation-name` in CoCo.

---

## File Format

Both skills and agents use the same file: `SKILL.md` with YAML frontmatter + markdown body.

### Frontmatter Fields

```yaml
---
name: my-skill-name          # must match directory name; lowercase, hyphens only
description: >               # shown in /skill list; also used for auto-activation matching
  One or two sentences. Say WHEN to use it and WHAT it does.
  Be specific — CoCo uses this to route requests automatically.
tools:                        # tools the skill/agent is allowed to use
  - bash                      # run shell commands
  - read                      # read files
  - write                     # create/overwrite files
  - edit                      # make targeted edits to files
model: auto                   # optional: auto | claude-sonnet-4-5 | claude-opus-4-5
---
```

**Rules:**
- `name`: lowercase letters, numbers, hyphens only — max 64 chars
- `description`: be specific about trigger conditions — CoCo uses it for auto-activation
- `tools`: only declare what the skill actually needs — `bash` is required if it runs commands
- `model`: omit to use session default; set `auto` to let CoCo pick based on task complexity

### Body

The markdown body is the system prompt — instructions for CoCo when the skill is active.

**Recommended structure:**
```markdown
## When to Use
- Bullet list of trigger conditions

## Output
- What the user gets back (tables, modified files, plan output)

## Goal
One sentence: what outcome does this skill produce?

## Steps
Numbered steps CoCo should follow

## Stopping Points
- ⚠ After [step] — wait for user approval before continuing
**Resume:** On "proceed" or "yes" — continue.

## Constraints
What CoCo must never do in this skill context

## Examples
### Example 1: <description>
User: `$skill-name <prompt>`
Assistant: <expected behavior>
```

Keep the body under ~400 lines. For reference material (stack mappings, HCL patterns),
put it in a `references/` directory and tell CoCo to read it on demand — avoids burning
tokens on every invocation.

---

## Building a Skill

### 1. Create the directory

```bash
mkdir -p .cortex/skills/my-skill
```

### 2. Write SKILL.md

```markdown
---
name: my-skill
description: Use when doing X. Generates Y and returns Z. Does not run apply.
tools:
  - bash
  - read
  - write
  - edit
---

# My Skill

## When to Use
- Scenario A
- Scenario B

## Output
- Modified `configs/*.tfvars`
- `terraform plan` output

## Steps
1. Read existing config file — match format exactly
2. Add new entry
3. Run plan via `scripts/stack-plan.sh`, return output

## Stopping Points
- ⚠ After generating config changes — show diff, wait for approval before running plan

## Constraints
- Never run terraform apply
- Never print credential file contents

## Examples

### Example 1
User: `$my-skill do thing A`
Assistant: Reads config, adds entry, returns plan command.
```

### 3. Verify CoCo finds it

Start a CoCo session from the project root, then:
```
/skill list
```
Your skill should appear. If not, confirm `.cortex/skills/my-skill/SKILL.md` exists.

### 4. Invoke it
```
$my-skill do the thing
```

---

## Building an Agent

Agents live in `.cortex/agents/` instead of `.cortex/skills/`. Same `SKILL.md` format,
but the body instructs autonomous execution rather than conversational guidance.

> **Note:** CoCo v1.0.28 may not support `.cortex/agents/` — only `.cortex/skills/` is confirmed.
> As a fallback, copy agent SKILL.md files into `.cortex/skills/` as well until agents/ support is confirmed.

### Autonomous Agent (runs to completion without asking)

Use when the task is well-defined and doesn't need human checkpoints mid-execution.

```markdown
---
name: my-agent
description: Autonomous agent that runs X across all Y and returns a consolidated report.
tools:
  - bash
  - read
model: auto
---

# My Agent

You are an autonomous agent. Execute all steps without waiting for user confirmation.
Do not ask clarifying questions. Complete the full task and report once at the end.

## Steps
1. For each item in [list], run [command]
2. Collect all outputs
3. Synthesize into a single report

## Output Format
[describe exact format of the final report]

## Hard Rules
- Never run destructive commands
- Never print credentials
```

Key phrase: **"You are an autonomous agent. Execute all steps without waiting for user confirmation."**

### Non-Autonomous Agent (pauses for human checkpoints)

Use when the task has steps that require human review before proceeding.

```markdown
---
name: my-agent
description: Non-autonomous agent for X. Runs pre-checks autonomously, then pauses
  for human confirmation before each subsequent step.
tools:
  - bash
  - read
model: auto
---

# My Agent

You are a non-autonomous agent. Run pre-checks autonomously, then pause for
human confirmation before proceeding to the next phase.

## Phase 1 — Pre-checks (run autonomously)
[commands to run and report on]

If any check fails, stop and explain what to fix. Do not proceed until all pass.

## Phase 2 — Hand off / execute
[what to do after pre-checks pass]

Tell the user: "Reply back if you hit an error or need help."

## Hard Rules
- Never skip a step
- Never proceed without pre-checks passing
```

---

## Routing Pattern (Parent Skill + Sub-Skills)

For complex domains, use a parent skill that routes to focused sub-skills and agents.
Keeps each context window lean — only the relevant instructions are loaded.

```
.cortex/
├── skills/
│   ├── my-agent/               ← parent router
│   │   └── SKILL.md            ← routing table only, stays lean
│   ├── my-agent-task-a/        ← focused sub-skill
│   │   └── SKILL.md
│   └── my-agent-task-b/
│       └── SKILL.md
└── agents/
    ├── my-agent-scan/          ← autonomous agent
    │   └── SKILL.md
    └── my-agent-walkthrough/   ← non-autonomous agent
        └── SKILL.md
```

**Parent skill routing table:**
```markdown
## Routing

| Request | Type | Invoke |
|---|---|---|
| Onboard new team | Skill | `$my-agent-task-a` |
| Scan for drift | Agent (autonomous) | `$my-agent-scan` |
| First-time setup | Agent (non-autonomous) | `$my-agent-walkthrough` |

**Agents** execute commands and report back.
**Skills** generate changes and commands for you to run.
```

---

## What's Built in This Repo

```
.cortex/
└── skills/
    ├── coco-iac-agent/                  ← parent router
    ├── coco-iac-agent-new-workload/     ← skill: onboard team (role + WH + schemas) — NAME PROPOSAL gate
    ├── coco-iac-agent-new-role-user/    ← skill: add user, RBAC changes — NAME PROPOSAL gate
    ├── coco-iac-agent-account-objects/  ← skill: resource monitors, network rules, EAIs — NAME PROPOSAL gate
    ├── coco-iac-agent-destroy/          ← skill: remove resources safely (dependency checks, prevent_destroy guard)
    ├── coco-iac-agent-promote-env/      ← skill: promote configs test → stage/prod with env suffix transformation
    ├── coco-iac-agent-plan-review/      ← skill: risk classification + standards compliance
    ├── coco-iac-agent-git-push/         ← skill: generate branch + commit + PR after apply
    ├── coco-iac-agent-drift-report/     ← autonomous: runs all 10 plans, returns report
    └── coco-iac-agent-bootstrap-guide/  ← non-autonomous: pre-flight checks + bootstrap script handoff
```

**Why drift-report is an autonomous agent:** runs `scripts/stack-plan.sh --drift` across 10 stacks and synthesises one consolidated report. No manual babysitting needed.

**Why bootstrap-guide is a non-autonomous agent:** runs pre-flight checks autonomously, then hands off to `bootstrap/bootstrap.sh` which handles the 10-stack orchestration with human-gated applies. Stays available to assist with errors during the script run.

**Why new-workload, new-role-user, account-objects, destroy, promote-env, plan-review, git-push are skills:** each is a focused single operation. Conversational, no multi-step autonomous execution needed.

**NAME PROPOSAL gate** (in `new-workload`, `new-role-user`, `account-objects`): before generating any tfvars, the skill reads `references/naming-conventions.md`, scans existing configs for conflicts, and presents proposed object names in a table. No files are touched until the user approves the names.

**Why destroy is a skill, not autonomous:** resource removal is irreversible. The skill requires explicit human confirmation of the tfvars diff before editing files, and again via `[y/N]` in `stack-apply.sh` before applying.

**Why promote-env is a skill, not autonomous:** promoting to prod is a high-stakes operation. Plan review and warehouse sizing decisions require human judgement per environment.

---

## Installing Skills

### Project-level (auto, no install needed)
Skills in `.cortex/` are loaded automatically when CoCo starts from that directory.
Commit `.cortex/` to git and every teammate gets the skills.

### From a git repo
```bash
# Inside a CoCo session
/skill add https://github.com/<org>/<repo>
```

### Global symlink install (for use from other repos)
```bash
mkdir -p ~/.snowflake/cortex/skills ~/.snowflake/cortex/agents
BASE="/path/to/this/repo/.cortex"

ln -sf "$BASE/skills/coco-iac-agent"                  ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-new-workload"     ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-new-role-user"    ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-account-objects"  ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-destroy"          ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-promote-env"      ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-plan-review"      ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-git-push"         ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-drift-report"     ~/.snowflake/cortex/skills/
ln -sf "$BASE/skills/coco-iac-agent-bootstrap-guide"  ~/.snowflake/cortex/skills/
```

**Path-with-spaces workaround:** If your repo path contains spaces, symlinks through `~/cortex-skills/` avoid CoCo's directory input breaking:
```bash
mkdir -p ~/cortex-skills
ln -sf "/path with spaces/repo/.cortex/skills/coco-iac-agent" ~/cortex-skills/coco-iac-agent
# Point CoCo to ~/cortex-skills instead
```

Verify: run `/skill list` in a CoCo session — all skills should appear.

---

## CLI Commands Reference

| Command | What it does |
|---|---|
| `$coco-iac-agent <prompt>` | Invoke a skill by name |
| `/skill list` | Show all loaded skills and agents |
| `/skill add <url>` | Install a skill from git |
| `/agents` | View background agent status |
| `Ctrl+B` | Open background process viewer |

---

## Common Workflows

| Task | Command |
|------|---------|
| Onboard a team | `$coco-iac-agent onboard MARKETING team in test` |
| Add a user | `$coco-iac-agent add user jsmith to ANALYST_ROLE in test` |
| Create a role | `$coco-iac-agent create DATA_ENG_ROLE in test` |
| Remove a user | `$coco-iac-agent remove JSMITH user from test` |
| Decommission a workload | `$coco-iac-agent decommission MARKETING squad from test` |
| Promote to prod | `$coco-iac-agent promote MARKETING workload from test to prod` |
| Check drift | `$coco-iac-agent-drift-report for test env` |
| Review a plan | `$coco-iac-agent-plan-review` + paste plan output |
| Bootstrap new env | `$coco-iac-agent bootstrap prod` |

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Skill not found | Directory name must match `name:` in frontmatter exactly |
| Agent keeps asking questions | Add "You are an autonomous agent. Execute without asking." to body |
| Non-autonomous agent doesn't pause | Add explicit stopping points with resume instruction |
| Too much context loaded every time | Move reference content to `references/` files, link from body |
| Skills not loading in CoCo | Confirm CoCo is launched from (or has access to) the `.cortex/` parent directory |
| Agent not found (v1.0.28) | Copy SKILL.md to `.cortex/skills/` as fallback |

---

## Smoke Test

After setup, run this in a CoCo session to validate the full routing chain:

```
$coco-iac-agent What can you do and what stacks does this repo manage?
```

Expected: parent skill loads, describes sub-skills and agents, reads `references/stack-mapping.md`, returns the 10-stack table.
