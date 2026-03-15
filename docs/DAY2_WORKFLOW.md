# Day-2 Operations Workflow

End-to-end guide for making infrastructure changes using CoCo skills.
Covers: generate → plan → apply → validate → summary.

---

## Prerequisites

- CoCo CLI running from repo root (`cortex -c <connection>`)
- `/skill list` shows all `coco-iac-agent*` skills
- Bootstrap completed (`bootstrap/bootstrap.sh <env>`)
- Snow CLI connection configured in `live/<env>/account.auto.tfvars`

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────┐
│  0. NAME PROPOSAL  CoCo proposes names, user approves        │
│  1. GENERATE       CoCo generates tfvars changes            │
│  2. REVIEW         Review the diff, confirm changes          │
│  3. PLAN           Run terraform plan for each stack         │
│  4. APPLY          Apply each stack in dependency order      │
│  5. STATE CHECK    Verify resources in terraform state       │
│  6. VALIDATE       Verify objects exist in Snowflake         │
│  7. COMPLIANCE     Check against Snowflake standards         │
│  8. SUMMARY        CoCo generates a change report            │
└─────────────────────────────────────────────────────────────┘
```

---

## Step 0 — Name Proposal

Before generating any tfvars, every creation skill (`new-workload`, `new-role-user`, `account-objects`) reads `references/naming-conventions.md`, scans existing configs for conflicts, and presents a name proposal table:

```
## Name Proposal — GROWTH squad — test

| Object Type        | Proposed Name       | Convention Applied      | Env Suffix  | Conflict |
|--------------------|---------------------|-------------------------|-------------|----------|
| Access role (read) | GROWTH_READ         | <OBJECT>_READ           | No (shared) | None     |
| Functional role    | GROWTH_ROLE_TEST    | <TEAM>_ROLE + _TEST     | Yes         | None     |
| Warehouse          | GROWTH_WH_TEST      | <TEAM>_WH + _TEST       | Yes         | None     |
| Schema             | ANALYTICS_DB.GROWTH_MART_TEST | purpose-based | Yes      | None     |

Approve these names, or reply with corrections before I generate any files.
```

**The skill will not read or modify any tfvars until you approve (or correct) the proposed names.**
This is the primary naming guardrail — catches convention violations and conflicts before any file is touched.

See `references/naming-conventions.md` for the full naming rules, derivation logic, and common mistake flags.

---

## Step 1 — Generate Changes with CoCo

Use the appropriate CoCo skill to generate tfvars changes.

### Onboard a New Team

```
$coco-iac-agent onboard the <TEAM> team in <env>:

Create new (add to existing tfvars):
  - Access role: <TEAM>_READ (or <TEAM>_WRITE) → create_role.tfvars
  - Functional role: <TEAM>_ROLE (under SYSADMIN, granted_roles: [<TEAM>_READ]) → create_role.tfvars
  - Warehouse: <TEAM>_WH (XSMALL, auto_suspend 60, auto_resume true) → create_warehouse.tfvars
  - Schemas: <SCHEMA1> and <SCHEMA2> in <DATABASE> → create_schema.tfvars

Users (add to create_users.tfvars):
  - <username>: <First> <Last>, <email>, <TEAM>_ROLE, <TEAM>_WH, workspace schema yes

Show me all tfvars changes and plan commands for each affected stack.
```

> Always add both an access role (privilege scope) and a functional role (assigned to humans). See `references/rbac-design.md` for the two-layer pattern.

### Add a User to Existing Role

```
$coco-iac-agent add user <username> to <ROLE> in <env>:
  first_name: <First>
  last_name: <Last>
  email: <email>
  warehouse: <WH>
  workspace schema: yes/no
Show me the tfvars change and plan command.
```

### Add Schemas Only

```
$coco-iac-agent add schemas <SCHEMA1>, <SCHEMA2> in <DATABASE> for <env>.
Show me the tfvars change and plan command.
```

---

## Step 2 — Review Changes

After CoCo generates the tfvars changes, review the diffs:

```bash
git diff live/<env>/configs/
```

Confirm:
- [ ] Object names are UPPERCASE
- [ ] No duplicate entries in tfvars maps
- [ ] Correct database assignments for schemas
- [ ] Correct role/warehouse assignments for users

---

## Step 3 — Plan

Run plans for each affected stack. CoCo outputs the commands — or use the helper script.

### Option A: CoCo-provided commands (manual, one at a time)

CoCo outputs commands like:
```bash
plan_out=$(mktemp)
bash scripts/stack-plan.sh <env> account_governance roles --run 2>&1 | tee "$plan_out"
bash scripts/scan-forcenew.sh "$plan_out"
```

Run each one, review the plan output, then move to the next.

### Option B: apply-changes.sh (automated, all stacks)

```bash
bash scripts/apply-changes.sh <env> <layer/stack> [<layer/stack> ...]
```

Example — onboarding a team touches 4 stacks:
```bash
bash scripts/apply-changes.sh test \
  account_governance/roles \
  platform/warehouses \
  workloads/schemas \
  account_governance/users
```

The script will:
1. `terraform init` + `terraform plan` for each stack
2. Scan for ForceNew (HIGH RISK flag)
3. Prompt `[y/N]` before each apply
4. Run post-apply validation via Snow CLI
5. Print a change summary

---

## Step 4 — Apply

**Always use `stack-apply.sh` — NEVER raw `terraform apply`.**

`stack-apply.sh` runs pre-flight checks, mandatory plan, and blocks unsafe applies:

| Safety Check | What it catches |
|-------------|-----------------|
| Config file exists | Missing `-var-file` → empty map → destroys all resources |
| Config not empty | Empty tfvars → same as missing |
| ForceNew detection | Database/warehouse/role replace = data loss |
| Destroy-only plan | 0 adds + N destroys = config not loaded |
| Empty for_each map | "key not in for_each map" = var-file dropped |
| Destroy > Add | More resources destroyed than created = suspicious |

### Apply individual stacks (recommended)

```bash
bash scripts/stack-apply.sh <env> <layer> <resource>
```

In dependency order:
```bash
bash scripts/stack-apply.sh test account_governance roles
bash scripts/stack-apply.sh test platform databases
bash scripts/stack-apply.sh test platform warehouses
bash scripts/stack-apply.sh test workloads schemas
bash scripts/stack-apply.sh test account_governance users
```

### Apply multiple stacks at once

```bash
bash scripts/apply-changes.sh test \
  account_governance/roles \
  platform/warehouses \
  workloads/schemas \
  account_governance/users
```

### Dependency order reference

| Order | Stack | Depends on |
|-------|-------|------------|
| 1 | roles | — |
| 2 | databases | — |
| 3 | warehouses | — |
| 4 | resource_monitors | — |
| 5 | schemas | databases |
| 6 | users | roles, warehouses |

---

## Step 5 — Terraform State Check

Verify new resources are tracked in Terraform state.

### If using apply-changes.sh
The script runs `terraform state list` for each applied stack automatically.

### Manual state check

```bash
# From repo root — list resources in each affected stack
cd live/<env>/account_governance/roles && terraform state list
cd ../../../.. && cd live/<env>/platform/warehouses && terraform state list
cd ../../../.. && cd live/<env>/workloads/schemas && terraform state list
cd ../../../.. && cd live/<env>/account_governance/users && terraform state list
```

To inspect a specific resource:
```bash
terraform state show 'module.role["<ROLE>"].snowflake_account_role.this'
terraform state show 'module.warehouse[0].snowflake_warehouse.this["<WH>"]'
terraform state show 'module.schema["<SCHEMA>"].snowflake_schema.this'
terraform state show 'module.users.snowflake_user.this["<username>"]'
```

### State check via CoCo

```
how to check the state of these resources in terraform state?
```

CoCo generates the correct `terraform state list` and `terraform state show` commands for each stack.

---

## Step 6 — Snowflake Validation

Verify objects actually exist in Snowflake.

### If using apply-changes.sh
The script runs Snow CLI validation queries automatically after apply.

### Manual validation via Snow CLI

```bash
# Roles
snow sql -c <connection> -q "SHOW ROLES LIKE '%_ROLE';"

# Warehouses
snow sql -c <connection> -q "SHOW WAREHOUSES LIKE '%_WH';"

# Schemas
snow sql -c <connection> -q "SHOW SCHEMAS IN DATABASE <DATABASE>;"

# Users
snow sql -c <connection> -q "SHOW USERS;"

# Role grants
snow sql -c <connection> -q "SHOW GRANTS OF ROLE <ROLE>;"

# Workspace schemas
snow sql -c <connection> -q "SHOW SCHEMAS IN DATABASE WORKSPACE_DB;"
```

### Validation via CoCo

After apply, ask CoCo to validate:
```
validate all resources created for <TEAM> team in <env> and generate a summary
```

CoCo runs the relevant SQL queries and produces a formatted report.

---

## Step 7 — Standards Compliance

Ask CoCo to verify resources follow Snowflake and repo standards:

```
show me current state and let me know everything is as per Snowflake standards
```

CoCo checks and reports on:

| Standard | What it checks |
|----------|---------------|
| Naming: UPPERCASE objects | Role, warehouse, schema, database names |
| Naming: `<TEAM>_ROLE` pattern | Functional role follows convention |
| Naming: `<TEAM>_WH` pattern | Warehouse follows convention |
| Access roles not assigned to users | Only functional roles in user `roles` list |
| Functional roles have `granted_roles` | Access roles wired into functional roles |
| Role hierarchy | All roles under SYSADMIN, not ACCOUNTADMIN |
| Workspace grants scoped to user's own roles | No blanket cross-team workspace access |
| Warehouse auto_suspend | Set (default 60s) |
| Warehouse auto_resume | Enabled |
| Schema owner | SYSADMIN |
| User default_role | Matches assigned functional role |
| User default_warehouse | Matches team warehouse |
| Workspace schemas | Created in WORKSPACE_DB, `create_workspace_schema = false` for service accounts |
| Provider v2.x resources | `snowflake_account_role`, not `snowflake_role` |
| No ACCOUNTADMIN grants | All resources under SECURITYADMIN/SYSADMIN |

---

## Step 8 — Summary

Ask CoCo to generate a shareable summary:
```
generate a summary of changes made for <TEAM> team lead
```

CoCo produces a formatted report with:
- All resources created (roles, warehouses, schemas, users)
- Configuration details (sizes, auto-suspend, role assignments)
- Standards compliance status
- Access summary
- Next steps (passwords, grants, MFA)

---

## Complete Example: Add a New Engineer

### 1. Generate

```
$coco-iac-agent add user kpatel to ENGINEER_ROLE in test:
  first_name: Kiran
  last_name: Patel
  email: kpatel@company.com
  warehouse: ENGINEER_WH
  workspace schema: yes, with extra privileges: CREATE PIPE, CREATE STREAM, CREATE TASK
Show me the tfvars change and plan command.
```

> ENGINEER_ROLE already inherits RAW_WRITE + ANALYTICS_READ + SHARED_READ via access roles — no role changes needed.

### 2. Review

```bash
git diff live/test/configs/create_users.tfvars
```

### 3–4. Plan & Apply

```bash
bash scripts/apply-changes.sh test account_governance/users
```

### 5. State check (in CoCo)

```
how to check the state of these resources in terraform state?
```

### 6. Validate (in CoCo)

```
validate kpatel user in test and confirm ENGINEER_ROLE is assigned
```

### 7. Standards compliance (in CoCo)

```
show me current state and let me know everything is as per Snowflake standards
```

### 8. Summary output

CoCo generates a report like:

```
Engineer Onboarding — Complete ✅
Environment: TEST
Date: 2026-03-10

Resources Created:
  - User: kpatel (Kiran Patel) — ENGINEER_ROLE, ENGINEER_WH
  - Workspace: WORKSPACE_DB.KPATEL (with CREATE PIPE, STREAM, TASK)

Role Inheritance (via access roles):
  ENGINEER_ROLE → RAW_WRITE (→ RAW_READ) + ANALYTICS_READ + SHARED_READ

Standards Compliance: All ✅

Next Steps:
  1. Set password or RSA key for kpatel
  2. Enroll in MFA
```

---

## Complete Example: Onboard New Team (Finance)

### 1. Generate

```
$coco-iac-agent onboard the Finance team in test:

Create new (add to existing tfvars):
  - Access role: FINANCE_READ (read-only on ANALYTICS_DB.MART + SHARED_DB) → create_role.tfvars
  - Functional role: FINANCE_ROLE (under SYSADMIN, granted_roles: [FINANCE_READ]) → create_role.tfvars
  - Warehouse: FINANCE_WH (XSMALL, auto_suspend 60, auto_resume true) → create_warehouse.tfvars
  - Schemas: BUDGETS and FORECASTS in ANALYTICS_DB → create_schema.tfvars

Users (add to create_users.tfvars):
  - rjones: Rachel Jones, rjones@company.com, FINANCE_ROLE, FINANCE_WH, workspace schema yes

Show me all tfvars changes and plan commands for each affected stack.
```

> When onboarding a new team, always add both an access role (defines what the team can see) and a functional role (assigned to humans, inherits the access role). See `references/rbac-design.md`.

### 2. Review

```bash
git diff live/test/configs/
```

Confirm:
- [ ] Access role has `parent_roles: ["SYSADMIN"]`
- [ ] Functional role has `granted_roles` pointing to the access role(s)
- [ ] No duplicate entries

### 3–4. Plan & Apply

```bash
bash scripts/apply-changes.sh test \
  account_governance/roles \
  platform/warehouses \
  workloads/schemas \
  account_governance/users
```

### 5–8. State, Validate, Compliance, Summary (same as above)

---

## Drift Detection

Detect manual changes and unmanaged objects (shadow IT) across all stacks.

### Run drift report

```
$coco-iac-agent run drift report for all stacks in test
```

CoCo runs two phases autonomously:
1. **Terraform state drift** — `terraform plan -detailed-exitcode` across all 10 stacks
2. **Unmanaged objects** — queries Snowflake via Snow CLI, compares against terraform state

Returns a consolidated report with HIGH RISK flags for any `# forces replacement` resources.

### Test with seed data

To try drift detection, run the seed SQL to create unmanaged objects in Snowflake:

```bash
snow sql -c <connection> -f examples/drift_detection_seed.sql
```

This creates a manual role, warehouse, schema, and user that the drift report will flag. Clean up with the commented-out DROP statements at the bottom of the file.

### Remediation options

| Drift Type | Action |
|-----------|--------|
| State drift (config changed outside TF) | Re-apply the stack to reconcile |
| Unmanaged object (should be in TF) | `$coco-iac-agent onboard <TEAM> in <env>` to generate tfvars, then import |
| Unmanaged object (test data) | DROP directly in Snowflake |

---

## Quick Reference

| Task | CoCo Prompt | Stacks Affected |
|------|-------------|-----------------|
| Onboard team (full) | `$coco-iac-agent onboard <TEAM> in <env>` | roles, warehouses, schemas, users |
| Add user (existing role) | `$coco-iac-agent add user <name> to <ROLE>` | users |
| Add schemas only | `$coco-iac-agent add schemas in <DB>` | schemas |
| Add role only | `$coco-iac-agent create <ROLE> in <env>` | roles |
| Add resource monitor | `$coco-iac-agent add monthly credit monitor in <env>` | platform/resource_monitors |
| Add network rule | `$coco-iac-agent add PyPI egress network rule in <env>` | platform/network_rules |
| Add external access integration | `$coco-iac-agent add PyPI access integration in <env>` | platform/external_access_integrations |
| Remove a resource | `$coco-iac-agent remove <NAME> from <env>` | varies (reverse order) |
| Decommission full workload | `$coco-iac-agent decommission <TEAM> from <env>` | roles, warehouses, schemas, users |
| Promote configs to prod | `$coco-iac-agent promote <TEAM> from test to prod` | roles, warehouses, schemas |
| Check drift | `$coco-iac-agent-drift-report for <env>` | all stacks (read-only) |
| Review plan output | `$coco-iac-agent-plan-review` + paste plan | — |
| Push changes to Git after apply | `$coco-iac-agent-git-push` | — |
