---
name: coco-iac-agent-destroy
description: Use when a user explicitly wants to remove one or more Snowflake resources — a user, service user, role, warehouse, schema, stage, network policy, account parameter, or full workload. Removes tfvars entries, runs plan to confirm expected destroys, scans for cascade effects and prevent_destroy blockers, then outputs the apply command for the human to run. Never runs apply or destroy directly.
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

# Destroy / Remove Resources

## When to Use
- User explicitly requests removal of one or more Snowflake objects
- Decommissioning a team or squad (full workload teardown)
- Removing a user who has left the organization
- Cleaning up test or dev resources after validation

## What This Skill Does NOT Do
- Remove databases with `prevent_destroy = true` — blocked by design
- Remove the provisioning user or TERRAFORM_ROLE — always blocked

---

## Inputs to Resolve First

Confirm from the user's request:
- **What to remove**: resource name(s) and type(s)
- **Environment**: `test` or `prod` (check `live/` for available envs)
- **Scope**: single resource or full workload

If ambiguous, ask ONE clarifying question.

---

## Steps

### Step 1 — Discover config files and map resource

Read `references/stack-mapping.md` for the authoritative resource → tfvars → stack mapping.

Scan `live/<env>/configs/` to find all available tfvars files:
```bash
ls live/<env>/configs/*.tfvars
```

### Step 2 — Pre-removal safety checks

**2a. `prevent_destroy` check:**
```bash
grep -r "prevent_destroy" live/<env>/
```
If target has `prevent_destroy = true` → **BLOCK**.

**2b. Downstream dependency check:**
- For roles: check if any user or service user has this role, or any other role references it in `granted_roles`
- For storage integrations: check if any stage references it
- For network rules: check if any external access integration references it
- For schemas: check if any stage references it
- For network policies: check if assigned to any user or to the account (`🔴 HIGH RISK — removing an account-level network policy can lock out all users`)
- For service users: check if any external system depends on this account (CI/CD, dbt, ETL)

**2c. Provisioning user guard:**
Read `provisioning_user` from `live/<env>/account.auto.tfvars`. If target matches → **BLOCK**.

**2d. Database/high-risk warning:**
If removing database → print `🔴 HIGH RISK — irreversible data loss` and require explicit confirmation.

### Step 3 — Show the diff

Print exactly what will be removed. **STOP** — wait for explicit user confirmation.

### Step 4 — Remove tfvars entries

Edit the identified tfvars file(s) — remove only confirmed keys.

**Removal order** (reverse of `stack-mapping.md` creation order):
- account_parameters → network_policies → stages → external_access_integrations → network_rules → schemas → resource_monitors → storage_integrations → warehouses → service_users → users → databases → roles

### Step 5 — Run plan for affected stacks

For each stack where entries were removed, run in reverse dependency order:
```bash
plan_out=$(mktemp)
bash scripts/stack-plan.sh <env> <layer> <resource> --run 2>&1 | tee "$plan_out"
bash scripts/scan-forcenew.sh "$plan_out"
```

**Review:** Expected = `N to destroy` matching what user asked. If more destroys than expected → **STOP** and explain cascade.

### Step 6 — Output apply commands

**NEVER run apply.** Output commands in reverse dependency order per `stack-mapping.md`:
```bash
bash scripts/stack-apply.sh <env> <layer> <resource>
```

### Step 7 — Post-apply validation

When user confirms apply done:
```bash
CONNECTION=$(grep snowsql_connection live/<env>/account.auto.tfvars | cut -d'"' -f2)
snow sql -q "SHOW <OBJECT_TYPE>S LIKE '<name>';" -c "$CONNECTION"
```
Expected: empty result.

### Step 8 — Git push prompt

> "Run `$coco-iac-agent-git-push` to commit these removal changes."

---

## Risk Summary

| Scenario | Risk | Action |
|---|---|---|
| Remove user | 🟢 LOW | Proceed after confirmation |
| Remove service user | 🟡 MEDIUM | Check no CI/CD or ETL depends on it |
| Remove role | 🟡 MEDIUM | Check dependencies first |
| Remove warehouse | 🟡 MEDIUM | Warn about query history loss |
| Remove schema | 🟡 MEDIUM | Warn about data loss |
| Remove stage | 🟢 LOW | Check no pipelines depend on it |
| Remove storage integration | 🟡 MEDIUM | Check no stages reference it |
| Remove network rule | 🟡 MEDIUM | Check no external access integrations reference it |
| Remove network policy | 🔴 HIGH | Check not assigned to account/users — removal can lock everyone out |
| Remove account parameter | 🟡 MEDIUM | Reverting to Snowflake default — verify impact |
| Remove database | 🔴 HIGH | Require explicit second confirmation |
| `prevent_destroy = true` | 🔴 BLOCKED | Cannot proceed |
| Provisioning user / TERRAFORM_ROLE | 🔴 BLOCKED | Cannot proceed |

---

## Constraints
- NEVER remove provisioning user or TERRAFORM_ROLE
- NEVER proceed past Step 3 without explicit user confirmation
- Resource removal is done via Terraform (remove tfvars entry → plan → user runs apply), NOT via direct SQL

All other safety rules enforced via `cortex ctx` rules. Run `cortex ctx rule list` to review.

## Guardrails
See `cortex ctx` rules — replaces `references/guardrails.md` for behavioral enforcement.

---

## Examples

### Example 1: Remove a single user
User: `remove user JSMITH from test`
→ Read create_users.tfvars, find entry, show diff, on confirmation remove, plan users stack, output apply command.

### Example 2: Decommission full workload
User: `remove MARKETING squad from test — role, warehouse, schemas`
→ Find all MARKETING entries across tfvars, check dependencies, show full diff, remove in reverse order, plan affected stacks, output apply commands.
