# Rules Reference — cortex ctx Rules for Snowflake IaC Agent

Two layers of behavioral rules enforced via `cortex ctx`:

- **Global rules** (`-g` flag) — apply across ALL projects/repos. Snowflake safety baseline.
- **Project rules** — apply only when CoCo is inside this repo folder.

Run `cortex ctx rule list` to see project rules. Run `cortex ctx show all` to see both layers (global tagged `[GLOBAL]`).

Storage:
- Project rules: `~/.snowflake/cortex/.ctx/<repo-folder-name>/memory.yaml`
- Global rules: `~/.snowflake/cortex/.ctx/` (shared namespace)

---

## Setup

New team member? Copy and run the commands below to replicate the full guardrail set.
Existing user? Run `cortex ctx show all` to compare — add any missing rules.

1. Run the **Global Rules** section first (these protect you in every project)
2. Then run the **Project Rules** sections from inside this repo folder

---

## Global Rules (18 rules — apply to ALL projects)

These form your Snowflake safety baseline. Run from any directory.

### SQL Safety
```bash
cortex ctx rule add -g "NEVER execute CREATE OR REPLACE on existing objects — suggest CREATE IF NOT EXISTS or ALTER instead"
cortex ctx rule add -g "NEVER execute TRUNCATE TABLE — output as code block for user to run"
cortex ctx rule add -g "NEVER execute DELETE without WHERE clause — output as code block for user to run"
cortex ctx rule add -g "NEVER execute DROP DATABASE, DROP SCHEMA, or DROP TABLE in production — output as code block for user to run"
cortex ctx rule add -g "read-only SQL (SELECT with LIMIT, SHOW, DESCRIBE, EXPLAIN, LIST) is always safe to execute autonomously"
```

### Role & Privilege Safety
```bash
cortex ctx rule add -g "NEVER execute REVOKE on system roles (ACCOUNTADMIN, SECURITYADMIN, SYSADMIN, ORGADMIN)"
cortex ctx rule add -g "NEVER grant anything TO ACCOUNTADMIN — refuse entirely"
cortex ctx rule add -g "NEVER execute ALTER ACCOUNT — refuse entirely"
cortex ctx rule add -g "NEVER modify system roles (ACCOUNTADMIN, SECURITYADMIN, ORGADMIN) — refuse entirely"
cortex ctx rule add -g "NEVER retry with higher privilege automatically on permission denied — show current role and suggest correct one"
```

### Credential Safety
```bash
cortex ctx rule add -g "NEVER hardcode account identifiers, passwords, or private keys in code or scripts — use env vars or file references"
cortex ctx rule add -g "NEVER display passwords, private keys, tokens, or connection strings with embedded credentials"
```

### Cost Safety
```bash
cortex ctx rule add -g "NEVER create XL or larger warehouses without explicit user confirmation — flag cost impact"
cortex ctx rule add -g "always add LIMIT to SELECT * on unknown or large tables — default LIMIT 1000"
cortex ctx rule add -g "flag queries scanning >100GB with cost estimate before execution"
```

### Environment & Core Principle
```bash
cortex ctx rule add -g "classify environment (prod vs non-prod) before any write operation — prod indicators: PROD, PRD, LIVE, MAIN in database/schema/role names"
cortex ctx rule add -g "NEVER create missing objects automatically in production on object-not-found — suggest correct schema or ask user"
cortex ctx rule add -g "read freely, write cautiously, destroy never — escalate ambiguity, don't assume"
```

---

## Project Rules (28 rules — this repo only)

Run these from inside the `snowflake-cortex-iac-agent` repo folder.

### 1. Environment & Workflow Defaults

```bash
cortex ctx rule add "default to test environment unless user specifies prod or stage"
cortex ctx rule add "after any tfvars edit, always run stack-plan.sh before suggesting apply"
cortex ctx rule add "after plan output, always wait for explicit user approval before proceeding to next step"
cortex ctx rule add "always remind stack execution order: roles → databases → users → warehouses → resource_monitors → storage_integrations → schemas → network_rules → external_access_integrations → stages"
```

## 2. Terraform Safety

```bash
cortex ctx rule add "NEVER execute stack-apply.sh, terraform apply, or terraform destroy — output command for user to run"
cortex ctx rule add "NEVER run raw terraform plan — always use scripts/stack-plan.sh"
cortex ctx rule add "forces replacement on database/warehouse/role = HIGH RISK — stop, explain risk, wait for explicit user decision"
cortex ctx rule add "never recreate existing Snowflake objects — always terraform import first, then adjust tfvars"
```

### 3. Git Safety

```bash
cortex ctx rule add "NEVER execute git commit, git push, or gh pr create — output commands for user to run"
cortex ctx rule add "NEVER push directly to main — always branch + PR"
cortex ctx rule add "NEVER run git add . — stage specific files only to avoid committing secrets or state files"
```

### 4. SQL Safety

```bash
cortex ctx rule add "NEVER execute destructive SQL (DROP, TRUNCATE, DELETE, CREATE OR REPLACE, REVOKE) — output for user to run"
```

### 5. Secrets & Credentials

```bash
cortex ctx rule add "NEVER print or read private key file contents (*.p8, *.pem) or account.auto.tfvars credential values"
```

### 6. Naming Conventions

```bash
cortex ctx rule add "all Snowflake object names UPPERCASE, all Terraform resource labels snake_case"
cortex ctx rule add "naming: roles=<TEAM>_ROLE, warehouses=<TEAM>_WH, databases=<PURPOSE>_DB, env suffix _TEST in test, _STAGE in stage, none in prod"
cortex ctx rule add "access roles have no env suffix (shared across envs), follow <OBJECT>_READ/<OBJECT>_WRITE pattern"
cortex ctx rule add "always present NAME PROPOSAL table and wait for user approval before editing any tfvars"
cortex ctx rule add "always check for name conflicts in existing tfvars before proposing new names"
```

### 7. RBAC — Two-Layer Model

```bash
cortex ctx rule add "access roles never assigned to users directly — only functional roles assigned to users, functional roles compose access roles via granted_roles"
cortex ctx rule add "all custom roles parented under SYSADMIN, never ACCOUNTADMIN — no ACCOUNTADMIN grants via Terraform ever"
cortex ctx rule add "one grant block per role per object type — multiple blocks cause perpetual drift"
cortex ctx rule add "use snowflake_account_role NOT snowflake_role, use snowflake_grant_privileges_to_account_role NOT snowflake_grant_privileges_to_role (v0.x deprecated)"
```

## 8. Resource-Specific

```bash
cortex ctx rule add "auto_suspend (<=60s) and auto_resume=true required on every warehouse"
cortex ctx rule add "flag any warehouse size above SMALL as a cost concern"
cortex ctx rule add "prevent_destroy=true on all databases and critical roles"
cortex ctx rule add "network rules must live in ADMIN_DB.GOVERNANCE — never in workload or user schemas"
cortex ctx rule add "provider alias ownership: secadmin=roles/users/network_rules, sysadmin=databases/warehouses/schemas/stages, accountadmin=resource_monitors/storage_integrations/external_access_integrations"
cortex ctx rule add "login_name change on existing user is ForceNew HIGH RISK — never change without explicit confirmation"
```

---

## Managing Rules

```bash
cortex ctx rule list                  # view project rules
cortex ctx show all                   # view all rules (project + global, globals tagged [GLOBAL])
cortex ctx rule add "<rule>"          # add a project rule (this repo only)
cortex ctx rule add -g "<rule>"       # add a global rule (across all projects)
```

To remove a rule, use the rule ID shown in `cortex ctx show all`:
```bash
cortex ctx forget <rule-id>
```

---

## Global Skills

Two global skills are registered via `cortex skill add` (apply across all projects):

| Skill | Path | Purpose |
|-------|------|---------|
| `sf-safety` | `~/.cortex/skills/sf-safety` | Safety tiers, error handling, emergency procedures |
| `snowflake-sql-review` | `~/.cortex/skills/snowflake-sql-review` | SQL classification, review workflow, output format |

Behavioral guardrails were extracted from these skills into global ctx rules. Skills now contain only procedural workflows (tier tables, checklists, templates).

```bash
cortex skill list                     # verify registered skills
cortex skill add <path>               # register a new global skill
```

---

## Origin

**Project rules** extracted from:
- `references/guardrails.md` — Terraform, Git, SQL safety
- `references/naming-conventions.md` — naming patterns, env suffixes
- `references/hcl-patterns.md` — provider aliases, v2.x resource names
- `references/rbac-design.md` — two-layer RBAC, role hierarchy
- `references/workflow.md` — ForceNew risk, plan approval gates
- All 10 `.cortex/skills/*/SKILL.md` — skill-specific constraints

**Global rules** extracted from:
- `~/.cortex/skills/sf-safety/SKILL.md` — SQL safety, credential safety, role safety, cost safety, environment classification
- `~/.cortex/skills/snowflake-sql-review/SKILL.md` — destructive SQL blocking, role restrictions

See `docs/coco_learning.md` for the full guide on how rules, memory, and tasks work together.
