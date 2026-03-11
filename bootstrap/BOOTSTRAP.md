# Bootstrap

One-time environment provisioning — applies all 10 stacks in dependency order.

Use bootstrap for a fresh environment. For day-2 changes (add a role, add a user, add a schema), edit the relevant `configs/*.tfvars` and re-apply just that one stack.

## Prerequisites

Install all required tools from the repo root:

```bash
brew bundle
```

This installs:
- Terraform CLI 1.9+
- Snow CLI (`snow`) — used by step 9 for `local-exec` SQL commands

Confirm Snow CLI connects before running the script:

```bash
snow sql -c <snowsql_connection value from account.auto.tfvars> -q "SELECT CURRENT_USER(), CURRENT_ROLE()"
```

Also ensure:
- `live/<env>/account.auto.tfvars` populated with connection details
- All `live/<env>/configs/*.tfvars` reviewed and updated for your environment

**Windows:** Native PowerShell is not supported — use Git Bash or WSL.

## macOS / Linux

```bash
chmod +x bootstrap.sh
./bootstrap.sh test      # or: ./bootstrap.sh prod
```

## How it works

The script walks through each stack in order.
- Runs `terraform plan` and **scans the plan output** for `# forces replacement`.
- If ForceNew is detected, the script **hard-stops (exit 2)** before any apply prompt.
- Otherwise it prompts you to confirm before every `apply`.

Skipping any step stops the script — re-run that stack manually from its directory when ready.

Each stack maintains its own `terraform.tfstate` in its own directory. There is no shared state between stacks. Cross-stack references use stable Snowflake object names, not Terraform IDs.

## Dependency order and why

| Step | Stack | Depends on |
|------|-------|-----------|
| 1 | `account_governance/roles` | nothing |
| 2 | `platform/databases` | nothing — but must precede users (workspace schemas) |
| 3 | `account_governance/users` | roles (step 1), WORKSPACE_DB (step 2) |
| 4 | `platform/warehouses` | roles (step 1) |
| 5 | `platform/resource_monitors` | nothing |
| 6 | `platform/storage_integrations_s3` | nothing |
| 7 | `workloads/schemas` | databases (step 2) — creates ADMIN_DB.GOVERNANCE |
| 8 | `platform/network_rules` | ADMIN_DB.GOVERNANCE schema (step 7) |
| 9 | `platform/external_access_integrations` | network rules (step 8), Snow CLI configured |
| 10 | `workloads/stages` | schemas (step 7), storage integrations (step 6) |

## Day-2 operations

After bootstrap, admins add objects by editing `configs/*.tfvars` and re-applying one stack.

**Always use `stack-apply.sh` for apply — never direct `terraform apply`.**
Direct `terraform apply` without the correct `-var-file` flags causes empty `for_each` maps, which Terraform interprets as "destroy all resources."

```bash
# Plan only
bash scripts/stack-plan.sh test account_governance roles --run

# Safe apply (plan + validation + apply)
bash scripts/stack-apply.sh test account_governance roles
bash scripts/stack-apply.sh test account_governance users
bash scripts/stack-apply.sh test workloads schemas
```

`stack-apply.sh` validates config files exist, runs a mandatory plan, blocks ForceNew and destroy-only plans, and prompts `[y/N]` before every apply.

No other stacks need to be touched when adding objects to an existing stack.

## Snow CLI step

Step 9 (`external_access_integrations`) invokes Snow CLI via `local-exec`. Before running that step:
- Confirm `snowsql_connection` in `account.auto.tfvars` matches your Snow CLI connection name
- Verify with: `snow sql -c <connection_name> -q "SELECT CURRENT_USER(), CURRENT_DATABASE()"`

## Guardrails

- Never re-run bootstrap on a live environment with existing state — it will try to recreate objects.
- `terraform plan` showing `# forces replacement` on a database, warehouse, or role is HIGH RISK — stop and investigate before applying.
- Applies are never automated — the script always prompts before each stack.
