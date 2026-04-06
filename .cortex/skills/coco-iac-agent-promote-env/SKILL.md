---
name: coco-iac-agent-promote-env
description: Use when promoting validated Snowflake infrastructure configs from one environment to another (test → prod). Reads source env tfvars, generates target env entries with correct naming (env suffixes, sizing), checks for existing objects, runs plan for the target env, and outputs apply commands. Never promotes without a plan review.
tools:
  - bash
  - read
  - write
  - edit
  - glob
---

## Skill Metadata
- **Last updated:** 2026-03-26
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# Promote Environment

## When to Use
- Test setup validated and ready to replicate to prod
- Rolling out a new team/workload to production after test sign-off
- Replicating specific resources to a higher environment

## What This Skill Does NOT Do
- Promote secrets, credentials, or private key content
- Promote the provisioning user or TERRAFORM_ROLE
- Promote objects that already exist in target (flags and skips)

---

## Inputs to Resolve First

Confirm from the user's request:
- **Source environment**: check `live/` for available envs (e.g., `test`)
- **Target environment**: check `live/` for available envs (e.g., `prod`)
- **Scope**: specific workload/resource names OR `all`
- **Warehouse sizing**: ask if promoting to prod — keep same or scale up?

---

## Steps

### Step 1 — Discover available configs

Scan both environments:
```bash
ls live/<source_env>/configs/*.tfvars
ls live/<target_env>/configs/*.tfvars
```

Read `references/stack-mapping.md` for resource → tfvars mapping.

### Step 2 — Identify entries to promote

**If scope = specific workload:** Extract matching keys from source.
**If scope = `all`:** Diff source vs target — entries in source but missing from target.

For each entry:
1. Apply env suffix transformation (see below)
2. Check if transformed key exists in target → skip if yes

**Env suffix rules:**

| Source | Target | Rule |
|---|---|---|
| `test` | `prod` | Remove `_TEST` suffix |
| Any other pattern | Ask user | Confirm naming convention |

**Handle `granted_roles`:** Transform referenced role names too. Verify all referenced roles exist in target.

### Step 3 — Warehouse sizing (if promoting to prod)

For each warehouse → ask:
> "Source warehouse `<name>` is `<size>`. Keep same for prod, or scale up?"

### Step 4 — Show promotion diff

Before any edits, show full proposed additions per tfvars file.

⚠️ **Users and service users are NOT promoted automatically** — credentials are env-specific. Note this and direct to `$coco-iac-agent-new-role-user`.

⚠️ **Account parameters may differ between environments** — review each parameter value for env-appropriateness (e.g., stricter session timeouts in prod). Do not blindly copy from test to prod.

⚠️ **STOP** — wait for explicit confirmation.

### Step 5 — Check if target objects already exist in Snowflake

Before running plan, query target Snowflake for existing objects:
```bash
CONNECTION=$(grep snowsql_connection live/<target_env>/account.auto.tfvars | cut -d'"' -f2)
snow sql -q "SHOW ROLES LIKE '<pattern>';" -c "$CONNECTION" --format json
snow sql -q "SHOW WAREHOUSES LIKE '<pattern>';" -c "$CONNECTION" --format json
```

**If objects exist in Snowflake but not in state:**
1. Add tfvars entries matching CURRENT Snowflake config
2. Use `terraform import` (see `references/stack-mapping.md` for import commands)
3. Run plan to verify zero changes
4. Then proceed with any desired config changes

### Step 6 — Apply changes to target env tfvars

Edit target tfvars files — ADD only new entries (never overwrite existing).

### Step 7 — Run plan for target env

Run plans in dependency order per `references/stack-mapping.md`:
```bash
plan_out=$(mktemp)
bash scripts/stack-plan.sh <target_env> <layer> <resource> --run 2>&1 | tee "$plan_out"
bash scripts/scan-forcenew.sh "$plan_out"
```

Present each plan. If unexpected destroys or `# forces replacement` → **STOP** and explain.

Expected: only `to add` — no changes to existing, no destroys.

### Step 8 — Output apply commands

**NEVER run apply.** Output commands in dependency order per `stack-mapping.md`:
```bash
bash scripts/stack-apply.sh <target_env> <layer> <resource>
```

### Step 9 — Post-apply validation

When user confirms done:
```bash
CONNECTION=$(grep snowsql_connection live/<target_env>/account.auto.tfvars | cut -d'"' -f2)
snow sql -q "SHOW ROLES LIKE '<pattern>';" -c "$CONNECTION"
```

### Step 10 — Git push prompt

> "Run `$coco-iac-agent-git-push` to commit these promotion changes."

---

## Key Rules
- **Never overwrite existing target entries** — only add new
- **Never promote user or service user entries** — always manual via `$coco-iac-agent-new-role-user` (credentials/keys are env-specific)
- **Account parameters require review** — values may need adjustment for target env (e.g., stricter settings in prod)
- **Network policies require review** — IP allowlists may differ between environments
- **Promotion = configs only** — data, query history, grants to external objects are not promoted

All other safety/naming rules enforced via `cortex ctx` rules. Run `cortex ctx rule list` to review.

## Guardrails
See `cortex ctx` rules — replaces `references/guardrails.md` for behavioral enforcement.

---

## Examples

### Example 1: Full workload promotion test → prod
User: `promote MARKETING workload from test to prod`
→ Find all MARKETING entries in test, transform names (strip `_TEST`), check prod tfvars for existing, check Snowflake for shadow objects, show diff, ask about warehouse sizing, on confirmation edit prod tfvars, run plans in order, output apply commands.

### Example 2: Partial promotion — role only
User: `promote FINANCE_ROLE from test to prod`
→ Extract role + its `granted_roles`, transform names, check if dependencies exist in prod, show diff, run role stack plan only.
