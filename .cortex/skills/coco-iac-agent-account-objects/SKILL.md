---
name: coco-iac-agent-account-objects
description: Use when adding or modifying account-level platform objects — resource monitors, network rules, network policies, external access integrations, or account parameters. Generates tfvars entries following the existing configs/ pattern and runs terraform plan for each affected stack.
tools:
  - bash
  - read
  - write
  - edit
---

## Skill Metadata
- **Last updated:** 2026-03-26
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# Account Objects

## When to Use
- Adding or modifying a resource monitor (credit quota, frequency)
- Adding a network rule (egress to PyPI, GitHub, external APIs)
- Adding an external access integration referencing existing network rules
- Adding or modifying a network policy (IP allowlist/blocklist)
- Setting or updating account parameters (timeouts, timezone, retention)
- Any combination of the above when wiring a new egress path end-to-end

## Goal
Add account-level platform objects — resource monitors, network rules, network policies, external access integrations, account parameters — with correct provider aliases, naming, and dependency ordering.
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

### Network Policies
- **Provider alias:** `accountadmin`
- **Stack:** `platform/network_policies`
- **Config:** `create_network_policies.tfvars`
- **Resource:** `snowflake_network_policy`
- Naming pattern: `<SCOPE>_NETWORK_POLICY` (e.g. `ACCOUNT_NETWORK_POLICY`, `OFFICE_NETWORK_POLICY`)
- Controls inbound IP access at account or user level
- `allowed_ip_list`: CIDRs allowed to connect
- `blocked_ip_list`: CIDRs explicitly blocked (evaluated after allowed)
- Can also reference network rules via `allowed_network_rule_list` / `blocked_network_rule_list`

⚠️ **HIGH RISK**: Assigning a network policy to the account (`ALTER ACCOUNT SET NETWORK_POLICY`) with a wrong `allowed_ip_list` locks out ALL users including the admin. Always validate the IP list before applying. The Terraform module creates the policy but does NOT assign it to the account — that's a separate manual step.

```hcl
# create_network_policies.tfvars
enable_network_policies = true
network_policies = {
  ACCOUNT_NETWORK_POLICY = {
    allowed_ip_list = ["203.0.113.0/24", "198.51.100.0/24"]
    blocked_ip_list = []
    comment         = "Account-level network policy — controls inbound access"
  }
}
```

### Account Parameters
- **Provider alias:** `accountadmin`
- **Stack:** `platform/account_parameters`
- **Config:** `create_account_parameters.tfvars`
- **Resource:** `snowflake_account_parameter`
- No naming pattern — keys are Snowflake parameter names (uppercase)
- Values are always strings, even for numeric/boolean parameters
- Common parameters: `STATEMENT_TIMEOUT_IN_SECONDS`, `TIMEZONE`, `DATA_RETENTION_TIME_IN_DAYS`, `PERIODIC_DATA_REKEYING`, `ENABLE_TRI_SECRET_NET`, `REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION`

```hcl
# create_account_parameters.tfvars
account_parameters = {
  STATEMENT_TIMEOUT_IN_SECONDS                   = "3600"
  TIMEZONE                                       = "America/New_York"
  DATA_RETENTION_TIME_IN_DAYS                    = "1"
  PERIODIC_DATA_REKEYING                         = "false"
  REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = "true"
}
```

## Dependency Order

These stacks must be applied in this sequence when all five are involved:

```
platform/resource_monitors              (independent — accountadmin)
platform/network_policies               (independent — accountadmin)
platform/account_parameters             (independent — accountadmin)
     ↓
workloads/schemas                       (ADMIN_DB.GOVERNANCE must exist before network rules)
     ↓
platform/network_rules                  (secadmin — depends on ADMIN_DB.GOVERNANCE schema)
     ↓
platform/external_access_integrations   (accountadmin — depends on network rules)
```

When adding only one or two object types, skip unaffected stacks.

## Importing Existing Objects vs Creating New

⚠️ **Always check if objects already exist before generating tfvars**

```sql
SHOW RESOURCE MONITORS;
SHOW NETWORK RULES IN SCHEMA ADMIN_DB.GOVERNANCE;
SHOW EXTERNAL ACCESS INTEGRATIONS;
SHOW NETWORK POLICIES;
SHOW PARAMETERS IN ACCOUNT;
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

# Network policies
terraform -chdir=live/<env>/platform/network_policies import \
  'module.network_policies.snowflake_network_policy.this["<POLICY_NAME>"]' '<POLICY_NAME>'

# Account parameters (no import needed — snowflake_account_parameter is idempotent;
# just add the key/value to tfvars and plan will show the correct diff)
```

## Steps

1. **Detect intent** — identify which object type(s) the user is adding (resource monitor, network rule, EAI, network policy, account parameter, or combination)
2. **NAME PROPOSAL** — before touching any file, read `references/naming-conventions.md`, scan the relevant existing tfvars for conflicts, then present:
   ```
   ## Name Proposal — <request summary> — <env>

   | Object Type              | Proposed Name                   | Convention Applied                    | Env Suffix | Conflict |
   |--------------------------|---------------------------------|---------------------------------------|------------|----------|
   | Resource monitor         | RM_MONTHLY_LIMIT[_TEST]         | RM_<SCOPE>_<LIMIT> + suffix           | Yes        | None     |
   | Network rule             | PYPI_NETWORK_RULE[_TEST]        | <PURPOSE>_NETWORK_RULE + suffix       | Yes        | None     |
   | External access integration | PYPI_ACCESS_INTEGRATION[_TEST] | <PURPOSE>_ACCESS_INTEGRATION + suffix | Yes        | None     |
   | Network policy           | ACCOUNT_NETWORK_POLICY[_TEST]   | <SCOPE>_NETWORK_POLICY + suffix       | Yes        | None     |
   | Account parameter        | (n/a — Snowflake param names)   | Uppercase Snowflake parameter name    | No         | n/a      |

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

   # Network policies (if changed)
   plan_out=$(mktemp)
   bash scripts/stack-plan.sh <env> platform network_policies --run 2>&1 | tee "$plan_out"
   bash scripts/scan-forcenew.sh "$plan_out"

   # Account parameters (if changed)
   plan_out=$(mktemp)
   bash scripts/stack-plan.sh <env> platform account_parameters --run 2>&1 | tee "$plan_out"
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
   bash scripts/stack-apply.sh <env> platform network_policies       # if changed
   bash scripts/stack-apply.sh <env> platform account_parameters     # if changed
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
     SHOW NETWORK POLICIES LIKE '<POLICY_NAME>';
     SHOW PARAMETERS IN ACCOUNT LIKE '<PARAM_KEY>';
     ```
   Do NOT ask "what's next?" — proceed directly to compliance check.
9. **COMPLIANCE** — check against standards (naming was pre-approved in NAME PROPOSAL — see `references/naming-conventions.md`):

   | Object Type | Non-naming Checks |
   |-------------|-------------------|
   | Resource monitors | `accountadmin` provider, `start_timestamp` commented or set to a future date |
   | Network rules | `secadmin` provider, lives in `ADMIN_DB.GOVERNANCE`, `mode = "EGRESS"` for outbound |
   | External access integrations | `accountadmin` provider, `allowed_network_rules` uses fully-qualified `DB.SCHEMA.RULE` references, `enabled = true` |
   | Network policies | `accountadmin` provider, `allowed_ip_list` is not empty (or has `0.0.0.0/0` placeholder), warn if assigning to account |
   | Account parameters | `accountadmin` provider, values are strings, keys are uppercase Snowflake parameter names |

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
- EAI `allowed_network_rules` must reference fully-qualified names: `"DB.SCHEMA.RULE_NAME"`
- `start_timestamp` on resource monitors must be a future datetime — if unknown, leave commented
- If EAI plan shows destroy/recreate on an existing integration, stop — flag SnowSQL escape hatch

All other safety/naming rules enforced via `cortex ctx` rules. Run `cortex ctx rule list` to review.

## Guardrails
See `cortex ctx` rules — replaces `references/guardrails.md` for behavioral enforcement.

## References
- `references/naming-conventions.md` — object naming patterns, NAME PROPOSAL format, conflict detection
- `references/guardrails.md` — safety rules, command format

## Output
- Modified `configs/create_resource_monitor.tfvars`, `create_network_rules.tfvars`, `create_external_access_integrations.tfvars`, `create_network_policies.tfvars`, `create_account_parameters.tfvars` (as applicable)
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

### Example 5: Add network policy
User: `$coco-iac-agent-account-objects add network policy for office IPs 203.0.113.0/24 in test`
Assistant: NAME PROPOSAL: `OFFICE_NETWORK_POLICY_TEST`. Reads `create_network_policies.tfvars`, adds entry with `allowed_ip_list = ["203.0.113.0/24"]`, `blocked_ip_list = []`. Runs plan for `platform/network_policies` — shows 1 to add. Warns: "This creates the policy but does NOT assign it to the account. To activate, run `ALTER ACCOUNT SET NETWORK_POLICY = 'OFFICE_NETWORK_POLICY_TEST';` after apply — ensure your current IP is in the allowed list first." Outputs apply command.

### Example 6: Set account parameters
User: `$coco-iac-agent-account-objects set statement timeout to 1800 and timezone to UTC in test`
Assistant: Reads `create_account_parameters.tfvars`, updates `STATEMENT_TIMEOUT_IN_SECONDS = "1800"` and `TIMEZONE = "UTC"`. Runs plan for `platform/account_parameters` — shows 2 to change. Outputs apply command.
