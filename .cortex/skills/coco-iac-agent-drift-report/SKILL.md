---
name: coco-iac-agent-drift-report
description: Autonomous skill that detects drift between Terraform state and live Snowflake objects. Runs two-phase detection — (1) terraform plan for state drift, (2) Snowflake queries for unmanaged objects. Returns consolidated drift report with HIGH RISK flags. Never asks clarifying questions — executes immediately and reports.
tools:
  - bash
  - read
model: auto
---

## Skill Metadata
- **Last updated:** 2026-03-12
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# Drift Report Skill

You are an autonomous skill. Execute all steps without waiting for user confirmation.
Do not ask clarifying questions. Run both phases, collect all results, then report once.

## When to Use
- Detecting manual changes made outside Terraform
- Finding unmanaged objects (shadow IT) created directly in Snowflake
- Pre-apply drift check before making new changes
- Scheduled drift audits for compliance
- Investigating unexpected state mismatches

## Stopping Points

None — this is fully autonomous. Execute all checks and report at the end.

## Your Job
Two-phase drift detection:
1. **Phase 1**: Run `terraform plan` across all stacks to detect state drift
2. **Phase 2**: Query Snowflake for objects not in Terraform state (unmanaged objects)

Synthesize results into a single consolidated report. Never apply anything.

## Inputs to Resolve First
Before executing, determine from the user's request:
- **Environment**: `test`, `stage`, or `prod` (default: `test` if not specified)
- **Scope**: `all` stacks (default) or a specific stack name

---

## Phase 1: Terraform State Drift

For each stack, run from the repo root:
```bash
bash scripts/stack-plan.sh <env> <layer> <resource> --run 2>&1 | tail -50
```

Stack sequence:
1. `account_governance/roles` → `create_role.tfvars`
2. `platform/databases` → `create_database.tfvars`
3. `account_governance/users` → `create_users.tfvars`
4. `platform/warehouses` → `create_warehouse.tfvars`
5. `platform/resource_monitors` → `create_resource_monitor.tfvars`
6. `platform/storage_integrations_s3` → `create_storage_integration_s3.tfvars`
7. `workloads/schemas` → `create_schema.tfvars`
8. `platform/network_rules` → `create_network_rules.tfvars`
9. `platform/external_access_integrations` → `create_external_access_integrations.tfvars`
10. `workloads/stages` → `create_stage_s3.tfvars`

### Exit Code Interpretation
- `No changes` in output → State matches live Snowflake
- `Plan: X to add, Y to change, Z to destroy` → Drift detected
- Error message → Record error and continue

---

## Phase 2: Unmanaged Objects Detection

**CRITICAL**: `terraform plan` cannot detect objects created directly in Snowflake that aren't in state. You must query Snowflake and compare.

### Step 2.1: Get Terraform-managed object names

```bash
# Roles in state
terraform -chdir=live/<env>/account_governance/roles state list 2>/dev/null | grep 'snowflake_account_role.this' | sed 's/.*\["//' | sed 's/"\]//'

# Warehouses in state
terraform -chdir=live/<env>/platform/warehouses state list 2>/dev/null | grep 'snowflake_warehouse.this' | sed 's/.*\["//' | sed 's/"\]//'

# Users in state
terraform -chdir=live/<env>/account_governance/users state list 2>/dev/null | grep 'snowflake_user.this' | sed 's/.*\["//' | sed 's/"\]//'

# Schemas in state
terraform -chdir=live/<env>/workloads/schemas state list 2>/dev/null | grep 'snowflake_schema.this' | sed 's/.*\["//' | sed 's/"\]//'

# Databases in state
terraform -chdir=live/<env>/platform/databases state list 2>/dev/null | grep 'snowflake_database.this' | sed 's/.*\["//' | sed 's/"\]//'
```

### Step 2.2: Query Snowflake for all objects

Use `snow sql` via bash with the connection name from `account.auto.tfvars` (`snowsql_connection`):

```bash
# Read connection name from tfvars
CONNECTION=$(grep snowsql_connection live/<env>/account.auto.tfvars | sed 's/.*= *"//' | sed 's/".*//')

# All custom roles (exclude system roles)
snow sql -q "SHOW ROLES;" -c "$CONNECTION" --format json

# All warehouses
snow sql -q "SHOW WAREHOUSES;" -c "$CONNECTION" --format json

# All users (exclude system users)
snow sql -q "SHOW USERS;" -c "$CONNECTION" --format json

# All databases
snow sql -q "SHOW DATABASES;" -c "$CONNECTION" --format json

# All schemas in managed databases (use database names from Step 2.1)
# For each database name from terraform state:
snow sql -q "SHOW SCHEMAS IN DATABASE <DB_NAME>;" -c "$CONNECTION" --format json
```

Filter out system objects (see "System Objects to Exclude" below).

### Step 2.3: Compare and identify unmanaged objects

For each object type, compare:
- Objects in Snowflake (from SHOW commands)
- Objects in Terraform state (from state list)

**Unmanaged** = exists in Snowflake but NOT in Terraform state

### System Objects to Exclude
Always exclude these from unmanaged object detection:

**Built-in System Objects:**
- **Roles**: ACCOUNTADMIN, SECURITYADMIN, SYSADMIN, USERADMIN, PUBLIC, ORGADMIN
- **Users**: SNOWFLAKE
- **Databases**: SNOWFLAKE, SNOWFLAKE_SAMPLE_DATA
- **Schemas**: INFORMATION_SCHEMA, PUBLIC (in each database)

**Snowflake-Provisioned Objects** (auto-created by Snowflake services):
- **Roles**: Any role starting with `SNOWFLAKE_` (e.g., SNOWFLAKE_LEARNING_ROLE)
- **Warehouses**: 
  - `COMPUTE_WH` (default trial warehouse)
  - Any warehouse starting with `SNOWFLAKE_` (e.g., SNOWFLAKE_LEARNING_WH)
  - Any warehouse starting with `SYSTEM$` (e.g., SYSTEM$STREAMLIT_NOTEBOOK_WH)
- **Users**: Any user starting with `SNOWFLAKE_`
- **Databases**: Any database starting with `SNOWFLAKE_`

**Pattern Matching for Exclusions:**
```sql
-- Exclude system warehouses
WHERE NAME NOT LIKE 'SNOWFLAKE_%' 
  AND NAME NOT LIKE 'SYSTEM$%'
  AND NAME != 'COMPUTE_WH'

-- Exclude system roles  
WHERE NAME NOT IN ('ACCOUNTADMIN','SECURITYADMIN','SYSADMIN','USERADMIN','PUBLIC','ORGADMIN')
  AND NAME NOT LIKE 'SNOWFLAKE_%'

-- Exclude system users
WHERE NAME NOT IN ('SNOWFLAKE')
  AND NAME NOT LIKE 'SNOWFLAKE_%'
```

---

## Consolidated Report Format

After both phases complete, output exactly this structure:

```
## Drift Report — <ENV> — <date>

### Phase 1: Terraform State Drift

| Stack | Status | Changes |
|---|---|---|
| account_governance/roles | ✅ OK | — |
| platform/databases | ⚠️ DRIFT | 1 resource changed |
| account_governance/users | ❌ ERROR | init failed: ... |
...

#### Drift Details (if any)

**platform/databases** — DRIFT
- `snowflake_database.ANALYTICS_DB` — update in-place
  - `data_retention_time_in_days`: 1 → 7

### Phase 2: Unmanaged Objects (Shadow IT)

| Object Type | Name | Owner | Comment |
|-------------|------|-------|---------|
| Role | SALES_ROLE | SECURITYADMIN | "Created manually" |
| Warehouse | SALES_WH | SYSADMIN | "Manual warehouse" |
| User | TSMITH | SECURITYADMIN | "Not in Terraform" |
| Schema | ANALYTICS_DB.SALES_MART | SYSADMIN | — |

### Risk Flags

🔴 HIGH RISK — <stack>: <resource> forces replacement
   Reason: <attribute> is ForceNew. Applying will destroy and recreate.
   Action required: Do not apply without explicit human decision.

🔴 HIGH RISK — <stack>: <resource> will be destroyed
   Reason: Resource removed from tfvars or state mismatch.
   Action required: Verify this is intentional before applying.

🔴 HIGH RISK — <stack>: <resource> is tainted
   Reason: Resource marked tainted will be destroyed and recreated on next apply.
   Action required: Run `terraform untaint` if destruction is not intended.

🟡 MEDIUM RISK — <stack>: <resource> update in-place (sensitive attribute)
   Reason: Changing <attribute> may disrupt active workloads.
   Action required: Schedule during maintenance window.

🟡 MEDIUM RISK — X unmanaged objects detected
   These objects are not tracked by Terraform and may cause issues.

✅ COSMETIC — <stack>: <resource> update in-place (metadata only)
   Reason: Only show_output refresh or default value additions.
   Action: Safe to apply or ignore.

### Summary
- Stacks checked: 10
- Clean: 8
- State drift: 1
- Errors: 1
- Unmanaged objects: 5
- HIGH RISK flags: 0

### Recommended Next Steps

**Reconciliation Philosophy: Two-Phase Approach**

#### Phase 1: Import & Stabilize (Initial Onboarding)
When bringing unmanaged objects under Terraform control:
- **Import** existing objects into state
- **Update tfvars** to match current Snowflake reality
- Goal: Get everything under management without breaking production

#### Phase 2: Enforce (Steady State)
Once objects are under management:
- **tfvars = source of truth** (desired state)
- **All changes** must go through: tfvars → PR review → apply
- **Drift = process violation** — investigate why someone bypassed Terraform

**Drift Investigation Workflow:**
```
Drift detected
     ↓
Ask: Was this change intentional?
     ↓
┌────┴────┐
│ YES     │ NO (unauthorized)
│         │
↓         ↓
Update    Apply to
tfvars    enforce
via PR    config
```

| Drift Type | Action | Rationale |
|------------|--------|-----------|
| Cosmetic (comments, defaults) | Update tfvars via PR | Low risk, accept reality |
| Config change (sizes, retention) | Investigate → PR or apply | Someone changed prod directly |
| New unmanaged object | Import + tfvars via PR | Shadow IT — bring under control |
| 🔴 ForceNew / Destroy | STOP — escalate | High risk, needs human decision |

**Key Rule:** Even when accepting Snowflake changes into tfvars, **always go through PR review** — this maintains audit trail and approval process.

**For state drift (config mismatches):**
1. First, check if drift is cosmetic (comments, descriptions, default values)
2. If cosmetic → update tfvars to match Snowflake reality **via PR**
3. If intentional config change → investigate who changed it and why
4. Only suggest `bash scripts/stack-apply.sh` for:
   - Intentional config enforcement (after PR approval)
   - New resources defined in tfvars but not yet created
   - 🔴 HIGH RISK situations requiring explicit human approval

**For unmanaged objects:**
⚠️ **ALWAYS use `terraform import` — NEVER recreate existing objects**

Recreating objects (via `terraform apply` without import) destroys and recreates them, causing:
- Data loss in warehouses (query history, resource monitors)
- Broken grants and role memberships
- User lockouts and credential resets

**Correct workflow:**
1. Add tfvars entries for unmanaged objects (matching current config)
2. Run `terraform import` to capture existing object in state
3. Run `terraform plan` to verify no changes (state matches reality)
4. Only then is the object under Terraform management

**Import commands by resource type:**
```bash
# Roles
terraform -chdir=live/<env>/account_governance/roles import 'module.role["<ROLE_NAME>"].snowflake_account_role.this' '<ROLE_NAME>'

# Warehouses
terraform -chdir=live/<env>/platform/warehouses import 'module.warehouse[0].snowflake_warehouse.this["<WH_NAME>"]' '<WH_NAME>'

# Users
terraform -chdir=live/<env>/account_governance/users import 'module.users.snowflake_user.this["<username>"]' '<username>'

# Schemas
terraform -chdir=live/<env>/workloads/schemas import 'module.schema["<SCHEMA_NAME>"].snowflake_schema.this' '"<DATABASE>"."<SCHEMA_NAME>"'
```

**Post-Import Validation** ⚠️ **AUTOMATIC** — after ALL imports complete:

Run plans on all affected stacks to verify state matches reality:
```bash
bash scripts/stack-plan.sh <env> account_governance roles --run 2>&1 | grep -E "(Plan:|to add|to change|to destroy|No changes|# forces replacement)"
bash scripts/stack-plan.sh <env> platform warehouses --run 2>&1 | grep -E "(Plan:|to add|to change|to destroy|No changes|# forces replacement)"
bash scripts/stack-plan.sh <env> workloads schemas --run 2>&1 | grep -E "(Plan:|to add|to change|to destroy|No changes|# forces replacement)"
bash scripts/stack-plan.sh <env> account_governance users --run 2>&1 | grep -E "(Plan:|to add|to change|to destroy|No changes|# forces replacement)"
```

Interpret and report:

| Plan Output | Status | Action |
|-------------|--------|--------|
| `No changes` | ✅ Perfect | Import successful |
| `X to change` (no destroy) | ⚠️ Config drift | Safe — tfvars differ from Snowflake config |
| `X to add` (grants/schemas) | ⚠️ Expected | Related resources need creation |
| `X to destroy` or `forces replacement` | 🔴 HIGH RISK | DO NOT APPLY — investigate mismatch |

If ForceNew detected: stop and ask user whether to fix tfvars/module or accept destroy/recreate.

- Option B (only for test/temp objects): Output DROP commands for user to run manually:
  ```sql
  -- Copy and run these commands yourself (CoCo will NOT execute them):
  DROP ROLE <name>;
  DROP WAREHOUSE <name>;
  DROP USER <name>;
  DROP SCHEMA <db>.<schema>;
  ```
```

## Hard Rules
Safety rules are enforced via `cortex ctx` rules. Run `cortex ctx rule list` to review.

Additional rules for drift report:
- SQL via `snow sql` is **read-only**: only `SHOW`, `DESCRIBE`, and `SELECT` queries — never DDL or DML
- Never print contents of `*.p8`, `*.pem`, or `account.auto.tfvars`
- If a stack errors on init, skip the plan for that stack and record the error; continue to next stack
- Do not stop on drift — run all checks regardless and report at the end
- Always run Phase 2 (unmanaged objects) even if Phase 1 shows no drift

---

## Risk Classification

Use `$coco-iac-agent-plan-review` for the authoritative risk classification tables and detection patterns.

For inline drift flagging, apply these quick rules:
- `# forces replacement` / `will be destroyed` / `is tainted` / `must be replaced` / `-/+` → 🔴 HIGH RISK
- `show_output` / `disable_mfa` / `mins_to_bypass_mfa` / `mins_to_unlock` / `comment` changes → ✅ COSMETIC
- Everything else → 🟡 MEDIUM — flag for review
