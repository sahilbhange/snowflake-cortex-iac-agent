---
name: coco-iac-agent-account-objects
description: Use when adding or modifying account-level platform objects — resource monitors, network rules, or external access integrations. Generates tfvars entries following the existing configs/ pattern and runs terraform plan for each affected stack.
tools:
  - bash
  - read
  - write
  - edit
---

## Skill Metadata
- **Last updated:** 2026-03-15
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# Account Objects

## When to Use
- Adding or modifying a resource monitor (credit quota, frequency)
- Adding a network rule (egress to PyPI, GitHub, external APIs)
- Adding an external access integration referencing existing network rules
- Any combination of the above when wiring a new egress path end-to-end

## Goal
Add account-level platform objects — resource monitors, network rules, external access integrations — with correct provider aliases, naming, and dependency ordering.
One tfvars change per affected stack, plan output for each.

## Object Types

### Resource Monitors
- **Provider alias:** `accountadmin`
- **Stack:** `platform/resource_monitors`
- **Config:** `create_resource_monitor.tfvars`
- **Resource:** `snowflake_resource_monitor`
- Naming pattern: `RM_<SCOPE>_<LIMIT>` (e.g. `RM_MONTHLY_LIMIT`, `RM_DAILY_LIMIT`)
- `frequency`: `MONTHLY`, `DAILY`, `WEEKLY`, `YEARLY`, or `NEVER`
- `start_timestamp`: optional; must be a future date/time — leave commented until known

```hcl
# create_resource_monitor.tfvars
resource_monitors = {
  RM_MONTHLY_LIMIT = {
    credit_quota = 500
    frequency    = "MONTHLY"
    # start_timestamp = "YYYY-MM-DD HH:MM"  # set a future timestamp
  }
}
```

### Network Rules
- **Provider alias:** `secadmin`
- **Stack:** `platform/network_rules`
- **Config:** `create_network_rules.tfvars`
- **Resource:** `snowflake_network_rule`
- Lives in `ADMIN_DB.GOVERNANCE` — that schema must exist before applying
- Naming pattern: `<PURPOSE>_NETWORK_RULE` (e.g. `PYPI_NETWORK_RULE`)
- `type`: `HOST_PORT` for egress by hostname; `AWSVPCEID` or `AWSSTS` for AWS-specific rules
- `mode`: `EGRESS` for outbound access control

```hcl
# create_network_rules.tfvars
network_rules = {
  PYPI_NETWORK_RULE = {
    database   = "ADMIN_DB"
    schema     = "GOVERNANCE"
    type       = "HOST_PORT"
    mode       = "EGRESS"
    value_list = [
      "pypi.org",
      "files.pythonhosted.org"
    ]
    comment = "PyPI egress for Snowpark Python UDFs"
  }
}
```

### External Access Integrations
- **Provider alias:** `accountadmin`
- **Stack:** `platform/external_access_integrations`
- **Config:** `create_external_access_integrations.tfvars`
- **Resource:** `snowflake_external_access_integration`
- Depends on network rules — reference by fully-qualified name: `"<DB>.<SCHEMA>.<RULE_NAME>"`
- Naming pattern: `<PURPOSE>_ACCESS_INTEGRATION`
- `allowed_api_integrations`: leave `[]` unless wiring an API integration object

⚠️ **SnowSQL escape hatch**: Some EAI operations (e.g. updating `allowed_network_rules` on an existing integration) may not be fully supported by the Terraform provider. If plan shows unexpected destroy/recreate on an existing EAI, fall back to the SnowSQL scripts in `live/<env>/platform/external_access_integrations/` and note this in the plan review.

```hcl
# create_external_access_integrations.tfvars
external_access_integrations = {
  PYPI_ACCESS_INTEGRATION = {
    enabled                  = true
    allowed_network_rules    = ["ADMIN_DB.GOVERNANCE.PYPI_NETWORK_RULE"]
    allowed_api_integrations = []
    comment                  = "Allows PyPI egress via network rule"
  }
}
```

## Dependency Order

These stacks must be applied in this sequence when all three are involved:

```
platform/resource_monitors        (independent — accountadmin)
     ↓
workloads/schemas                 (ADMIN_DB.GOVERNANCE must exist before network rules)
     ↓
platform/network_rules            (secadmin — depends on ADMIN_DB.GOVERNANCE schema)
     ↓
platform/external_access_integrations  (accountadmin — depends on network rules)
```

When adding only one or two object types, skip unaffected stacks.

## Importing Existing Objects vs Creating New

⚠️ **Always check if objects already exist before generating tfvars**

```sql
SHOW RESOURCE MONITORS;
SHOW NETWORK RULES IN SCHEMA ADMIN_DB.GOVERNANCE;
SHOW EXTERNAL ACCESS INTEGRATIONS;
```

**If objects already exist:**
1. Add tfvars entries matching the CURRENT Snowflake config exactly
2. Use `terraform import` to bring them into state
3. Run plan to verify zero changes
4. Only then modify tfvars to desired state

**Import commands:**
```bash
# Resource monitors
terraform -chdir=live/<env>/platform/resource_monitors import \
  'module.resource_monitor["<RM_NAME>"].snowflake_resource_monitor.this' '<RM_NAME>'

# Network rules
terraform -chdir=live/<env>/platform/network_rules import \
  'module.network_rule["<RULE_NAME>"].snowflake_network_rule.this' '"ADMIN_DB"."GOVERNANCE"."<RULE_NAME>"'

# External access integrations
terraform -chdir=live/<env>/platform/external_access_integrations import \
  'module.external_access_integration["<EAI_NAME>"].snowflake_external_access_integration.this' '<EAI_NAME>'
```

## Steps

1. **Detect intent** — identify which object type(s) the user is adding (resource monitor, network rule, EAI, or combination)
2. **NAME PROPOSAL** — before touching any file, read `references/naming-conventions.md`, scan the relevant existing tfvars for conflicts, then present:
   ```
   ## Name Proposal — <request summary> — <env>

   | Object Type              | Proposed Name                   | Convention Applied                    | Env Suffix | Conflict |
   |--------------------------|---------------------------------|---------------------------------------|------------|----------|
   | Resource monitor         | RM_MONTHLY_LIMIT[_TEST]         | RM_<SCOPE>_<LIMIT> + suffix           | Yes        | None     |
   | Network rule             | PYPI_NETWORK_RULE[_TEST]        | <PURPOSE>_NETWORK_RULE + suffix       | Yes        | None     |
   | External access integration | PYPI_ACCESS_INTEGRATION[_TEST] | <PURPOSE>_ACCESS_INTEGRATION + suffix | Yes        | None     |

   Approve these names, or reply with corrections before I generate any files.
   ```
   **GATE: Do not read or edit any tfvars until the user approves names.**
3. **Prerequisite check** — before generating any tfvars:
   - For network rules: verify `ADMIN_DB.GOVERNANCE` schema exists: `SHOW SCHEMAS IN DATABASE ADMIN_DB LIKE 'GOVERNANCE'`
   - For EAIs: verify referenced network rules exist in `create_network_rules.tfvars` (or already in Snowflake)
4. Read the relevant tfvars file(s) — match format exactly
5. Add entries (using approved names) following tfvars patterns above
6. **REVIEW** — show all tfvars diffs, wait for explicit user confirmation before proceeding
6. **PLAN** — run plans for affected stacks in dependency order (always scan for ForceNew):

   ```bash
   # Resource monitors (if changed)
   plan_out=$(mktemp)
   bash scripts/stack-plan.sh <env> platform resource_monitors --run 2>&1 | tee "$plan_out"
   bash scripts/scan-forcenew.sh "$plan_out"

   # Network rules (if changed)
   plan_out=$(mktemp)
   bash scripts/stack-plan.sh <env> platform network_rules --run 2>&1 | tee "$plan_out"
   bash scripts/scan-forcenew.sh "$plan_out"

   # External access integrations (if changed)
   plan_out=$(mktemp)
   bash scripts/stack-plan.sh <env> platform external_access_integrations --run 2>&1 | tee "$plan_out"
   bash scripts/scan-forcenew.sh "$plan_out"
   ```

   Present each plan summary, wait for approval before applying. If EAI plan shows destroy/recreate on an existing integration, stop and flag the SnowSQL escape hatch.

7. **APPLY** — output apply commands in dependency order, wait for user to confirm completion of each:
   ```bash
   bash scripts/stack-apply.sh <env> platform resource_monitors      # if changed
   bash scripts/stack-apply.sh <env> platform network_rules          # if changed
   bash scripts/stack-apply.sh <env> platform external_access_integrations  # if changed
   ```
8. **POST-APPLY** ⚠️ **AUTOMATIC** — when user confirms apply completed, immediately run:
   - **State check**: `terraform -chdir=<stack> state list | grep <resource>` for each affected stack
   - **Snowflake validation**:
     ```sql
     SHOW RESOURCE MONITORS LIKE '<RM_NAME>';
     SHOW NETWORK RULES IN SCHEMA ADMIN_DB.GOVERNANCE LIKE '<RULE_NAME>';
     SHOW EXTERNAL ACCESS INTEGRATIONS LIKE '<EAI_NAME>';
     ```
   Do NOT ask "what's next?" — proceed directly to compliance check.
9. **COMPLIANCE** — check against standards (naming was pre-approved in NAME PROPOSAL — see `references/naming-conventions.md`):

   | Object Type | Non-naming Checks |
   |-------------|-------------------|
   | Resource monitors | `accountadmin` provider, `start_timestamp` commented or set to a future date |
   | Network rules | `secadmin` provider, lives in `ADMIN_DB.GOVERNANCE`, `mode = "EGRESS"` for outbound |
   | External access integrations | `accountadmin` provider, `allowed_network_rules` uses fully-qualified `DB.SCHEMA.RULE` references, `enabled = true` |

10. **SUMMARY** — generate formatted change report:
    - All objects created (names, types, key config)
    - Dependency chain confirmed (network rule → EAI, if applicable)
    - Standards compliance status (N/N checks passed)
    - Next steps (assign network rule to UDF/procedure, attach EAI to Snowpark function, etc.)
11. **GIT PUSH** — after summary, always prompt:
    > "Config files have been updated. Run `$coco-iac-agent-git-push` to generate the branch, commit message, and PR commands for these changes."

## Naming Rules
See `references/naming-conventions.md` — canonical source for all patterns, env suffix rules, conflict detection, and the NAME PROPOSAL table format.

## Constraints
- Never run `terraform apply` or `terraform destroy` — output `scripts/stack-apply.sh` command for the user to run manually
- Never run destructive SQL (`DROP`, `TRUNCATE`, `DELETE`, `CREATE OR REPLACE`) — output commands for user to run manually
- Network rules must live in `ADMIN_DB.GOVERNANCE` — never in a workload or user-owned schema
- EAI `allowed_network_rules` must reference fully-qualified names: `"DB.SCHEMA.RULE_NAME"` — not just the rule name
- `start_timestamp` on resource monitors must be a future datetime — if unknown, leave commented
- If EAI plan shows destroy/recreate on an existing integration, stop — flag SnowSQL escape hatch before proceeding

## Guardrails
Read `references/guardrails.md` before proceeding — all safety rules, command format, and stopping points live there.

## References
- `references/naming-conventions.md` — object naming patterns, NAME PROPOSAL format, conflict detection
- `references/guardrails.md` — safety rules, command format

## Output
- Modified `configs/create_resource_monitor.tfvars`, `create_network_rules.tfvars`, `create_external_access_integrations.tfvars` (as applicable)
- `terraform plan` output for each affected stack in dependency order
- Risk summary if any `# forces replacement` or unexpected destroy detected on existing EAIs

## Examples

### Example 1: New resource monitor
User: `$coco-iac-agent-account-objects add monthly credit monitor, 500 credits, test env`
Assistant: Reads `create_resource_monitor.tfvars`, adds `RM_MONTHLY_LIMIT_TEST` with `credit_quota = 500`, `frequency = "MONTHLY"`. Runs plan for `platform/resource_monitors`. Shows 1 to add. Outputs apply command.

### Example 2: New egress path (network rule + EAI)
User: `$coco-iac-agent-account-objects add PyPI egress network rule and EAI in prod`
Assistant: Checks ADMIN_DB.GOVERNANCE schema exists. Reads `create_network_rules.tfvars` — adds `PYPI_NETWORK_RULE` with `HOST_PORT`/`EGRESS` pointing to pypi.org and files.pythonhosted.org. Reads `create_external_access_integrations.tfvars` — adds `PYPI_ACCESS_INTEGRATION` referencing `ADMIN_DB.GOVERNANCE.PYPI_NETWORK_RULE`. Runs plans for `platform/network_rules` then `platform/external_access_integrations`. Shows diffs, waits for approval between stacks. Outputs apply commands in order.

### Example 3: Network rule only (EAI exists)
User: `$coco-iac-agent-account-objects add GitHub egress rule to existing PYPI_ACCESS_INTEGRATION in prod`
Assistant: Reads `create_network_rules.tfvars` — adds `GITHUB_NETWORK_RULE`. Reads `create_external_access_integrations.tfvars` — appends `ADMIN_DB.GOVERNANCE.GITHUB_NETWORK_RULE` to `PYPI_ACCESS_INTEGRATION.allowed_network_rules`. Flags: updating `allowed_network_rules` on an existing EAI may trigger destroy/recreate — checks plan carefully. If plan shows destroy on EAI, stops and flags SnowSQL escape hatch.

### Example 4: EAI destroy/recreate detected
Plan output shows: `snowflake_external_access_integration.pypi will be destroyed` (forces replacement)
Assistant: Stops. Flags HIGH RISK — EAI destroy will break any UDFs or Snowpark functions currently referencing it. Points to `live/<env>/platform/external_access_integrations/` SnowSQL scripts as the safe path for in-place update. Does NOT output apply command.
