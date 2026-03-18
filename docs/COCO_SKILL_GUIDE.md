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
- `CORTEX.md` is the project instruction file — auto-loaded at session start
- `.cortex/skills/` with `SKILL.md` files deliver skill-specific context
- `.cortex/settings.local.json` controls hooks and permissions
- `~/.claude/CLAUDE.md` is the global user preferences file (optional)

### Skill Design Best Practices

Embed domain rules in `CORTEX.md` (project-level) and skill `SKILL.md` files:

```
CORTEX.md                                  ← project rules, always loaded
.cortex/skills/coco-iac-agent/SKILL.md     ← skill-specific instructions
```

**Design principles:**
- **Primary source of truth:** `CORTEX.md` for project-wide rules
- **Skill-specific context:** `.cortex/skills/<name>/SKILL.md` for focused instructions
- **Always place skills in `.cortex/skills/`** — ensures they're found by CoCo
- **Prompt style:** Write instructions in plain, imperative English. Markdown headings, bullet lists, and tables work universally.

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

---

## CoCo Configuration Files

CoCo uses several configuration files at different scopes. Here's how they're used in this repo:

### File Hierarchy (Load Order)

| File | Scope | Auto-loaded? | Purpose |
|------|-------|--------------|---------|
| `~/.claude/CLAUDE.md` | Global (user) | ✅ Yes | Personal preferences across all projects |
| `CORTEX.md` | Project | ✅ Yes | Project instructions, domain rules, safety guardrails |
| `.cortex/settings.local.json` | Project | ✅ Yes | Hooks, permissions, local overrides |
| `.cortex/BANNER.md` | Project | Via hook | Session start banner (requires SessionStart hook) |
| `.cortex/skills/*/SKILL.md` | Project | On invoke | Skill-specific instructions |
| `references/*.md` | Project | On demand | Domain knowledge read by skills |

### CORTEX.md — Project Instructions

The primary project instruction file. Auto-loaded at session start.

**Location:** Project root (`/CORTEX.md`)

**What to put here:**
- Domain rules that apply to ALL interactions (not just skill invocations)
- Safety guardrails (NEVER/ALWAYS rules)
- Naming conventions summary
- Skill routing guard (reminder to use skills)
- Provider aliases and role hierarchy

**This repo's CORTEX.md contains:**
- Terraform safety rules (never apply, never destroy)
- Git safety rules (never push, never commit)
- SQL safety rules (no destructive SQL)
- Skill routing table
- Provider alias mapping
- Naming conventions

### .cortex/settings.local.json — Hooks & Permissions

Controls CoCo behavior: what's auto-approved, what's blocked, what runs at session start.

**Location:** `.cortex/settings.local.json`

**Structure:**
```json
{
  "hooks": {
    "SessionStart": [...],
    "PreToolUse": [...]
  },
  "permissions": {
    "allow": [...]
  }
}
```

#### SessionStart Hooks

Run commands when a CoCo session begins. Used for banners, environment checks.

```json
"SessionStart": [
  {
    "hooks": [
      {
        "type": "command",
        "command": "cat .cortex/BANNER.md"
      }
    ]
  }
]
```

#### PreToolUse Hooks (Safety Guardrails)

Block dangerous operations before they execute. Pattern-matched against tool calls.

```json
"PreToolUse": [
  {
    "matcher": "Bash(terraform apply*)",
    "hooks": [{ "type": "reject", "message": "Use scripts/stack-apply.sh manually" }]
  },
  {
    "matcher": "Bash(terraform destroy*)",
    "hooks": [{ "type": "reject", "message": "Destructive op - run manually" }]
  },
  {
    "matcher": "Bash(git push*)",
    "hooks": [{ "type": "reject", "message": "Push manually after review" }]
  },
  {
    "matcher": "Bash(git commit*)",
    "hooks": [{ "type": "reject", "message": "Commit manually after review" }]
  }
]
```

**How matchers work:**
- Only the specific pattern is blocked
- `Bash(terraform apply*)` blocks `terraform apply`, `terraform apply -auto-approve`
- Does NOT block `terraform plan`, `terraform init`, etc.

#### Permissions Allow List

Auto-approve specific tools/commands without prompting.

```json
"permissions": {
  "allow": [
    "Read",
    "Glob",
    "Grep",
    "Edit",
    "WebFetch(domain:docs.snowflake.com)",
    "WebFetch(domain:registry.terraform.io)",
    "WebFetch(domain:github.com)",
    "WebFetch(domain:raw.githubusercontent.com)",
    "Bash(terraform init*)",
    "Bash(terraform plan*)",
    "Bash(terraform validate*)",
    "Bash(terraform fmt*)",
    "Bash(scripts/stack-plan.sh*)",
    "Bash(git status*)",
    "Bash(git diff*)",
    "Bash(git log*)",
    "Bash(git branch*)",
    "Bash(ls*)",
    "Bash(pwd)"
  ]
}
```

**This repo's settings:**
- Auto-approve: Read, Glob, Grep, Edit (file operations)
- Auto-approve: Safe terraform commands (init, plan, validate, fmt)
- Auto-approve: Read-only git commands (status, diff, log, branch)
- Auto-approve: WebFetch for Snowflake docs and Terraform registry
- Block: terraform apply, terraform destroy, git push, git commit

### .cortex/BANNER.md — Session Banner

Displayed at session start via SessionStart hook. Not auto-loaded — requires hook config.

**Location:** `.cortex/BANNER.md`

**Example:**
```
  +---+---+---+---+
  | C | o | C | o |  IaC Agent
  +---+---+---+---+  Snowflake · Terraform
  
  Use $coco-iac-agent to get started
  AI plans · You review · You apply
```

**Tips:**
- Use ASCII art (not Unicode box-drawing) for terminal compatibility
- Keep it short — 5-6 lines max
- Include the main entry point skill name

### references/ — Domain Knowledge

Reference documents that skills read on-demand. Keeps skill context lean.

**Location:** `references/*.md`

**This repo's references:**
| File | Purpose |
|------|---------|
| `guardrails.md` | Safety rules, stopping points |
| `naming-conventions.md` | Object naming, NAME PROPOSAL format |
| `stack-mapping.md` | Stack execution order, provider aliases |
| `hcl-patterns.md` | Copy-paste HCL blocks for every resource type |
| `rbac-design.md` | Two-layer RBAC model, privilege matrix |
| `workflow.md` | Day-2 operation workflows |

**Why separate from skills:**
- Avoids burning tokens on every skill invocation
- Skills read only what they need: `Read references/naming-conventions.md`
- Single source of truth — update once, all skills get the change

---

## cortex ctx — Memory & Context

CoCo can remember information across sessions using `cortex ctx`.

### Commands

| Command | Purpose |
|---------|---------|
| `cortex ctx remember "fact"` | Store a memory |
| `cortex ctx forget <id>` | Remove a memory |
| `cortex ctx list` | Show all memories |
| `cortex ctx rule add "rule"` | Add a behavioral rule |
| `cortex ctx rule list` | Show all rules |
| `cortex ctx rule remove <id>` | Remove a rule |

### Use Cases

**Personal preferences:**
```
cortex ctx remember "Prefer XS warehouse size for test environments"
cortex ctx remember "Always use snake_case for Terraform resource labels"
```

**Behavioral rules:**
```
cortex ctx rule add "Never auto-commit changes"
cortex ctx rule add "Always show plan output before suggesting apply"
```

### Where It's Stored

Memories are stored in `~/.claude/` and persist across sessions. They're user-scoped, not project-scoped.

---

## Complete CoCo Feature Summary

| Feature | Location | Purpose | Used in This Repo |
|---------|----------|---------|-------------------|
| `CORTEX.md` | Project root | Project instructions (auto-loaded) | ✅ Domain rules, safety guardrails |
| `.cortex/skills/` | Project | Skill definitions | ✅ 10 skills for IaC operations |
| `.cortex/settings.local.json` | Project | Hooks, permissions | ✅ Safety blocks, auto-approvals |
| `.cortex/BANNER.md` | Project | Session banner | ✅ Entry point reminder |
| `references/` | Project | Domain knowledge | ✅ 6 reference docs |
| `~/.claude/CLAUDE.md` | User global | Personal preferences | User-specific |
| `cortex ctx` | User global | Cross-session memory | Optional |

---

## Recommended Setup for New Projects

1. **Create CORTEX.md** — project instructions, safety rules
2. **Create .cortex/skills/** — at minimum a router skill
3. **Create .cortex/settings.local.json** — block dangerous ops, auto-approve safe ones
4. **Create .cortex/BANNER.md** — remind users of entry point
5. **Create references/** — domain knowledge for skills to read on-demand

```bash
mkdir -p .cortex/skills/my-router
touch CORTEX.md
touch .cortex/BANNER.md
touch .cortex/settings.local.json
touch .cortex/skills/my-router/SKILL.md
mkdir -p references
```
