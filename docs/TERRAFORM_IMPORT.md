# Adopting an Existing Snowflake Account into Terraform

This guide explains how to bring an existing Snowflake account under Terraform management using this repository’s stacks. The process is safe and incremental: you first mirror the live configuration into variables, then import state for each resource, and only after achieving a zero‑drift plan do you begin making changes via Terraform.

## Goals

- Capture the current state of an existing account without recreating resources
- Bind Terraform state to existing Snowflake objects via imports
- Establish guardrails to avoid accidental destructive changes
- Use this project’s environment structure (test/stage/prod) to standardize operations

## Prerequisites

- Terraform CLI v1.5+ and Snowflake provider
- SnowSQL on `PATH` for `local-exec` workflows (database renames, external access integrations)
- Read-only Snowflake role(s) to start (for discovery), and elevated roles when you are ready to manage changes (SECURITYADMIN, SYSADMIN, ACCOUNTADMIN as appropriate)
- Optional: Remote state backend configured (S3/DynamoDB or Terraform Cloud)

## Step 1 — Choose environment mapping

- Decide which `live/<env>` directory represents the existing account (e.g., adopt into `live/stage` or create `live/prod`). You can replicate the structure by copying an existing env folder and updating its `account.auto.tfvars`.
- Agree on naming conventions, including environment-aware suffixes (e.g., `_TEST`, `_STAGE`, blank for production). See FUTURE_SCOPE.md for planned dynamic naming helpers.

## Step 2 — Inventory existing resources

Use SnowSQL or Snowsight to enumerate objects you plan to manage:

- Databases: `show databases;`
- Warehouses: `show warehouses;`
- Roles: `show roles;`
- Users: `show users;`
- Network rules / external integrations: use `show` commands or account usage views

Record names, comments, retention, sizes, and any constraints you must preserve. This becomes input to the `configs/*.tfvars` files.

## Step 3 — Mirror live configuration into `configs/*.tfvars`

Populate the environment’s config files so they describe what already exists, for example:

```hcl
# live/<env>/configs/create_database.tfvars
databases = {
  EXISTING_DB = {
    comment                     = "Existing database"
    data_retention_time_in_days = 7
  }
}
```

Repeat for warehouses, users, roles, network rules, storage/external integrations, and schemas/stages. The closer these values match reality, the less drift Terraform will detect.

## Step 4 — Dry-run with refresh-only

From each stack directory (e.g., `live/<env>/platform/databases`):

```bash
terraform init -upgrade
terraform plan -refresh-only \
  -var-file=../../account.auto.tfvars \
  -var-file=../../configs/create_database.tfvars
```

This confirms whether Terraform can read the existing objects. Expect “no changes” for resources you will import later; if the plan shows it wants to create resources, that’s a signal to import state first.

## Step 5 — Import existing resources

Bind Terraform state to each live object. Using examples aligned with this repo’s modules:

```bash
# Databases
terraform import \
  'module.database["EXISTING_DB"].snowflake_database.this' \
  EXISTING_DB

# Warehouses
terraform import \
  'module.warehouse["EXISTING_WH"].snowflake_warehouse.this' \
  EXISTING_WH

# Roles
terraform import \
  'module.role["EXISTING_ROLE"].snowflake_account_role.this' \
  EXISTING_ROLE

# Users
terraform import \
  'module.user["existing.user"].snowflake_user.this' \
  existing.user
```

Tips:
- For Terraform v1.5+, you can use `import` blocks in configuration and run `terraform apply` to perform multiple imports in one go.
- Import IDs follow the Snowflake object name (or provider-specific ID) unless the provider docs specify a composite key.

### Optional: Config-driven imports (Terraform 1.5+)

Instead of running many `terraform import` CLI commands, declare imports in code. Create an `imports.tf` file inside the stack you are adopting (e.g., `live/<env>/platform/databases`) and add blocks like the following. On `terraform apply`, Terraform will import each resource into state without changing it.

```hcl
# Example: Databases
import {
  to = module.database["EXISTING_DB"].snowflake_database.this
  id = "EXISTING_DB"
}

# Example: Warehouses
import {
  to = module.warehouse["EXISTING_WH"].snowflake_warehouse.this
  id = "EXISTING_WH"
}

# Example: Roles
import {
  to = module.role["SECURITY_ENGINEER"].snowflake_account_role.this
  id = "SECURITY_ENGINEER"
}

# Example: Users
import {
  to = module.user["existing.user"].snowflake_user.this
  id = "existing.user"
}
```

Run:

```bash
terraform init -upgrade
terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/<your_config>.tfvars
terraform apply  # performs the imports declared above
```

Notes:
- The `to` address must match the resource’s module path and `for_each` key exactly.
- After a successful import, the block becomes a no-op. You can keep `imports.tf` for traceability or remove it.

## Step 6 — Verify zero drift

Run a normal plan and ensure it reports “No changes.” If differences remain, align your `configs/*.tfvars` to match live settings or, where appropriate, use `lifecycle` customizations (see next step) to suppress noisy fields you do not intend to manage.

## Step 7 — Add guardrails before enabling writes

- Set `lifecycle { prevent_destroy = true }` for critical resources (e.g., production databases, core roles/warehouses).
- Consider `lifecycle { ignore_changes = [comment, owner, ...] }` for attributes that remain outside Terraform control.
- Start with a read-only provider alias to validate plans, then switch to write-capable roles when ready to apply.
- Use remote state (per-stack) to improve collaboration and drift detection.

## Step 8 — Manage changes going forward

- Use the standard `plan` → `apply` cycle in each stack. Track changes in version control.
- For operations the provider cannot do in-place (e.g., database rename), use the dedicated SnowSQL workflow in `live/<env>/platform/database_rename` and follow its state alignment steps. See also `RENAMING_LIMITATIONS.md` for why Terraform treats renames as recreate operations.
- For external access integrations, ensure a SnowSQL profile with appropriate role (ACCOUNTADMIN) is configured prior to apply.

## Common pitfalls and remedies

- Name mismatches or case sensitivity: ensure your keys (e.g., `databases` map keys) match Snowflake object names exactly.
- Unmanaged privileges: adopt grants thoughtfully to avoid revoking required access; stage grant resources behind "ignore_changes" until ready to fully manage.
- Provider ForceNew fields: changing names forces recreation. Use SnowSQL workflows plus `terraform state mv`/`import` instead of direct renames.
- Secrets handling: avoid committing keys; prefer environment variables or secret stores.

## Example adoption checklist

1) Pick env folder (`live/stage` or `live/prod`) and set `account.auto.tfvars`.
2) Inventory resources via `show` commands.
3) Mirror objects into `configs/*.tfvars`.
4) `terraform plan -refresh-only` in each stack.
5) Import all existing resources.
6) Confirm zero drift with `terraform plan`.
7) Add guardrails (`prevent_destroy`, `ignore_changes`).
8) Begin managing changes, using SnowSQL workflows where required.

Following this sequence lets you safely adopt an existing Snowflake account without downtime or unintended replacement of core objects, while preparing the ground for CI/CD and policy enforcement.

## Next steps

- Add a minimal, commented `imports.tf` template to each stack directory (e.g., `account_governance/roles`, `platform/databases`, `platform/warehouses`, `workloads/schemas`, `workloads/stages`). Teams can uncomment and fill in the resource keys/IDs to perform bulk, reviewable imports via Terraform 1.5+.
