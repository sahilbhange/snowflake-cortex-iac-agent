# Terraform Commands Reference

Raw Terraform commands for all 10 stacks — no helper scripts, no wrappers.
Use this as a cheat sheet, for CI integration, or to understand what the scripts do under the hood.

> **Recommended path:** Use `bash scripts/stack-plan.sh <env> <layer> <resource> --run` and `bash scripts/stack-apply.sh <env> <layer> <resource>` — they add pre-flight checks, ForceNew detection, and a human confirmation prompt. This file is for users who want direct Terraform control.

> **Critical:** Always pass both `-var-file` flags. Missing either one causes Terraform to use empty defaults → empty `for_each` map → plan shows destroy of all resources.

All commands run from the repo root. Replace `<env>` with `test` or `prod`.

---

## Credentials

**Option A — tfvars file** (recommended, already gitignored)

Populate `live/<env>/account.auto.tfvars` — Terraform picks it up automatically via `auto.tfvars` naming.

**Option B — environment variables**

```bash
export SNOWFLAKE_ORGANIZATION_NAME="your_org"
export SNOWFLAKE_ACCOUNT_NAME="your_account"
export SNOWFLAKE_USER="your_user"
export TF_VAR_private_key_path="~/.snowflake/rsa_key.p8"
export TF_VAR_query_tag="terraform"
```

---

## All 10 stacks

### Init (run once per stack, or after provider version changes)

```bash
terraform -chdir=live/<env>/account_governance/roles               init -upgrade
terraform -chdir=live/<env>/platform/databases                     init -upgrade
terraform -chdir=live/<env>/account_governance/users               init -upgrade
terraform -chdir=live/<env>/platform/warehouses                    init -upgrade
terraform -chdir=live/<env>/platform/resource_monitors             init -upgrade
terraform -chdir=live/<env>/platform/storage_integrations_s3       init -upgrade
terraform -chdir=live/<env>/workloads/schemas                      init -upgrade
terraform -chdir=live/<env>/platform/network_rules                 init -upgrade
terraform -chdir=live/<env>/platform/external_access_integrations  init -upgrade
terraform -chdir=live/<env>/workloads/stages                       init -upgrade
```

### Plan (review before every apply)

```bash
terraform -chdir=live/<env>/account_governance/roles              plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_role.tfvars
terraform -chdir=live/<env>/platform/databases                    plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_database.tfvars
terraform -chdir=live/<env>/account_governance/users              plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_users.tfvars
terraform -chdir=live/<env>/platform/warehouses                   plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_warehouse.tfvars
terraform -chdir=live/<env>/platform/resource_monitors            plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_resource_monitor.tfvars
terraform -chdir=live/<env>/platform/storage_integrations_s3      plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_storage_integration_s3.tfvars
terraform -chdir=live/<env>/workloads/schemas                     plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_schema.tfvars
terraform -chdir=live/<env>/platform/network_rules                plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_network_rules.tfvars
terraform -chdir=live/<env>/platform/external_access_integrations plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_external_access_integrations.tfvars
terraform -chdir=live/<env>/workloads/stages                      plan -var-file=../../account.auto.tfvars -var-file=../../configs/create_stage_s3.tfvars
```

### Apply (in dependency order — do not skip steps)

```bash
terraform -chdir=live/<env>/account_governance/roles              apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_role.tfvars
terraform -chdir=live/<env>/platform/databases                    apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_database.tfvars
terraform -chdir=live/<env>/account_governance/users              apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_users.tfvars
terraform -chdir=live/<env>/platform/warehouses                   apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_warehouse.tfvars
terraform -chdir=live/<env>/platform/resource_monitors            apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_resource_monitor.tfvars
terraform -chdir=live/<env>/platform/storage_integrations_s3      apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_storage_integration_s3.tfvars
terraform -chdir=live/<env>/workloads/schemas                     apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_schema.tfvars
terraform -chdir=live/<env>/platform/network_rules                apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_network_rules.tfvars
terraform -chdir=live/<env>/platform/external_access_integrations apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_external_access_integrations.tfvars
terraform -chdir=live/<env>/workloads/stages                      apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_stage_s3.tfvars
```

---

## Single stack (day-2 changes)

For a day-2 change, run only the stack whose config changed:

```bash
# Example: roles config changed
terraform -chdir=live/<env>/account_governance/roles plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_role.tfvars
terraform -chdir=live/<env>/account_governance/roles apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_role.tfvars
```

---

## ForceNew scan

Save plan output and check for replacement risk before applying:

```bash
terraform -chdir=live/<env>/account_governance/roles plan -no-color \
  -var-file=../../account.auto.tfvars \
  -var-file=../../configs/create_role.tfvars \
  | tee plan.out

bash scripts/scan-forcenew.sh plan.out   # exit 2 on ForceNew — stop and investigate
```

`# forces replacement` on a database, warehouse, or role = HIGH RISK (drop + recreate = data loss).

---

## Drift detection

Use `-detailed-exitcode` to get machine-readable exit codes for CI or scripting:

```bash
terraform -chdir=live/<env>/account_governance/roles plan -detailed-exitcode \
  -var-file=../../account.auto.tfvars \
  -var-file=../../configs/create_role.tfvars
# exit 0 = no changes
# exit 1 = error
# exit 2 = changes detected (drift or pending resources)
```

---

## State inspection

```bash
# List all tracked resources in a stack
terraform -chdir=live/<env>/account_governance/roles state list

# Show details of a specific resource
terraform -chdir=live/<env>/account_governance/roles state show 'snowflake_account_role.this["ANALYST_ROLE"]'
```

---

## Dependency order reference

| Step | Stack | Config file | Key dependency |
|------|-------|-------------|----------------|
| 1 | `account_governance/roles` | `create_role.tfvars` | None — first stack |
| 2 | `platform/databases` | `create_database.tfvars` | Before users — WORKSPACE_DB must exist |
| 3 | `account_governance/users` | `create_users.tfvars` | Databases (step 2) |
| 4 | `platform/warehouses` | `create_warehouse.tfvars` | Roles (step 1) |
| 5 | `platform/resource_monitors` | `create_resource_monitor.tfvars` | None |
| 6 | `platform/storage_integrations_s3` *(SnowSQL)* | `create_storage_integration_s3.tfvars` | SnowSQL required |
| 7 | `workloads/schemas` | `create_schema.tfvars` | Databases (step 2) — creates ADMIN_DB.GOVERNANCE |
| 8 | `platform/network_rules` | `create_network_rules.tfvars` | ADMIN_DB.GOVERNANCE (step 7) |
| 9 | `platform/external_access_integrations` *(SnowSQL)* | `create_external_access_integrations.tfvars` | Network rules (step 8) |
| 10 | `workloads/stages` | `create_stage_s3.tfvars` | Schemas (step 7), storage integrations (step 6) |
