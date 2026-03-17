# CoCo Learning Guide — cortex ctx for IaC Projects

How to use `cortex ctx` (rules, memory, tasks) to make CoCo skills lighter, faster, and more enforceable.

---

## What is cortex ctx?

`cortex ctx` is CoCo's persistent context system. It stores rules, memories, and tasks that survive across sessions — meaning CoCo starts every session already knowing your project conventions, safety guardrails, and team-specific facts.

```bash
cortex ctx show all    # see everything loaded
cortex ctx rule list   # see active rules
cortex ctx search "warehouse"  # search memory
```

---

## Three Pillars

### 1. Rules — "How to behave"

Rules enforce behavioral guardrails. They load at session start and apply to every interaction, whether or not a skill is invoked.

Two scopes:
- **Project rules** — apply only inside the repo folder where they were added
- **Global rules** (`-g` flag) — apply across ALL projects/repos (Snowflake safety baseline)

```bash
cortex ctx rule add "NEVER execute terraform apply — output command for user"
cortex ctx rule add -g "NEVER execute DROP TABLE in production — output as code block"
cortex ctx rule list       # view project rules
cortex ctx show all        # view both layers (globals tagged [GLOBAL])
```

**Best for:** safety guardrails, naming conventions, cost policies, workflow requirements.

Storage:
- Project: `~/.snowflake/cortex/.ctx/<repo-folder-name>/memory.yaml`
- Global: `~/.snowflake/cortex/.ctx/` (shared namespace)

### 2. Memory — "What to know"

Memory stores facts about your project, team, and account. CoCo uses these to avoid re-reading files or asking repetitive clarifying questions.

```bash
cortex ctx remember "existing functional roles: ENGINEER, TRANSFORMER, ANALYST, MARKETING, REPORTER, DATA_PLATFORM, CI, FINANCE, SALES, ETL, GROWTH"
cortex ctx remember "ADMIN_DB.GOVERNANCE schema must exist before network_rules stack"
cortex ctx search "roles"  # search stored facts
```

**Best for:** team structure, existing objects, account-specific facts, dependency notes.

### 3. Tasks — "What to do"

Tasks track multi-step infrastructure work across sessions. Useful when onboarding a workload touches 4+ stacks in order.

```bash
cortex ctx task add "onboard ML_PLATFORM team"
cortex ctx task start 1
# work through stacks...
cortex ctx task done
cortex ctx task list       # see status
```

**Best for:** multi-stack operations, interrupted work, onboarding checklists.

---

## How Rules Interact with Skills

```
Session starts
    |
    ├── Global ctx rules load (Snowflake safety baseline — all projects)
    ├── Project ctx rules load (repo-specific guardrails)
    ├── cortex ctx memories load (project facts)
    ├── Global skills load (sf-safety, snowflake-sql-review — registered via cortex skill add)
    |
    └── User invokes $coco-iac-agent-new-workload
         |
         ├── Skill provides: step-by-step workflow, HCL templates, examples
         ├── Global rules enforce: SQL safety, credential protection, cost limits
         ├── Project rules enforce: naming conventions, stack ordering, plan-before-apply
         └── Memory provides: existing roles, team patterns, account facts
```

**Skills = what to do.** Step-by-step workflow, HCL patterns, stack ordering.
**Rules = how to behave.** Safety stops, naming enforcement, cost guardrails.
**Memory = what to know.** Team context, existing state, account-specific facts.

Global rules + global skills = Snowflake safety baseline (every project gets them).
Project rules + project skills = repo-specific conventions (only this repo).

---

## Token Cost Reduction

Before rules, every skill invocation required CoCo to:
1. Read `references/guardrails.md` (88 lines)
2. Read `references/naming-conventions.md` (166 lines)
3. Read `references/workflow.md` (57 lines)
4. Process duplicated NEVER statements in each skill's Constraints section

With rules, these behavioral guardrails load automatically at session start as compact key-value pairs. Skills no longer need to embed or reference them — they focus purely on workflow logic.

**Estimated savings:** ~200-300 tokens per skill invocation (no redundant file reads).

---

## Rules vs Memory — When to Use Which

| Scenario | Use | Why |
|----------|-----|-----|
| "Never run terraform apply" | Rule | Behavioral enforcement |
| "Default to test env" | Rule | Session-wide default |
| "Flag LARGE warehouses" | Rule | Cost policy |
| "ENGINEER_WH is the only LARGE warehouse" | Memory | Project fact |
| "GROWTH team was most recently onboarded" | Memory | Historical context |
| "storage integrations need SnowSQL escape hatch" | Memory | Dependency note |
| "Use snowflake_account_role not snowflake_role" | Rule | Standard enforcement |
| "RAW_DB has schemas: SALESFORCE, STRIPE, EVENTS" | Memory | Existing state |

**Rule of thumb:** If CoCo should **do or not do** something → rule. If CoCo should **know** something → memory.

---

## Setting Up Rules for a New Team Member

All rules for this project are documented in `docs/RULES_REFERENCE.md` with exact `cortex ctx rule add` commands. A new team member can run the full setup script to replicate the guardrails:

```bash
# From the repo root
cat docs/RULES_REFERENCE.md  # review all rules
# Copy and run the cortex ctx rule add commands
```

Rules are stored per-user at `~/.snowflake/cortex/.ctx/` — each team member manages their own rule set. Project rules are scoped per repo folder, so rules from different projects never interfere.

---

## Architecture Decision: Why Rules over Skill-Embedded Guardrails

### Problem
- 10 skills each embedded identical NEVER statements (apply, destroy, SQL, git, secrets)
- Every skill said "Read `references/guardrails.md` before proceeding" — burning tokens
- Adding a new guardrail required editing 10+ files
- Guardrails were invisible outside skill context (ad-hoc questions bypassed them)

### Solution
- Extract behavioral rules into `cortex ctx` rules (persistent, session-wide)
- Use two scopes: global rules (`-g`) for Snowflake safety baseline, project rules for repo-specific conventions
- Register global skills via `cortex skill add` for procedural workflows (tier tables, SQL review format)
- Skills retain only workflow logic (steps, templates, examples) and skill-specific constraints
- References retain only data tables (HCL patterns, RBAC matrix, stack mapping)
- One `RULES_REFERENCE.md` documents everything — single source of truth for humans

### Result
- Skills are ~15-30% lighter (fewer lines, no redundant NEVER sections)
- Rules enforce even outside skill context (ad-hoc questions hit the same guardrails)
- Global rules protect every project (dbt, Streamlit, etc.) without duplicating skills
- Adding a new guardrail = one `cortex ctx rule add` command + update RULES_REFERENCE.md
- Token cost per session reduced (no redundant file reads for behavioral rules)
- Current totals: 18 global rules + 28 project rules = 46 rules, 2 global skills
