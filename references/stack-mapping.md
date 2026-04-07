# Stack Mapping

## Ordered Execution
Apply in this sequence — 13 stacks total. Steps 11-13 have no upstream dependencies and can run after bootstrap:

| Step | Stack | Config File | Key Dependency |
|------|-------|-------------|----------------|
| 1 | `account_governance/roles` | `create_role.tfvars` | None — first stack |
| 2 | `platform/databases` | `create_database.tfvars` | Before users — WORKSPACE_DB must exist |
| 3 | `account_governance/users` | `create_users.tfvars` | Databases (step 2) |
| 4 | `platform/warehouses` | `create_warehouse.tfvars` | Roles (step 1) |
| 5 | `platform/resource_monitors` | `create_resource_monitor.tfvars` | None |
| 6 | `platform/storage_integrations_s3` | `create_storage_integration_s3.tfvars` | SnowSQL required |
| 7 | `workloads/schemas` | `create_schema.tfvars` | Databases (step 2) — creates ADMIN_DB.GOVERNANCE |
| 8 | `platform/network_rules` | `create_network_rules.tfvars` | ADMIN_DB.GOVERNANCE (step 7) |
| 9 | `platform/external_access_integrations` | `create_external_access_integrations.tfvars` | Network rules (step 8), SnowSQL |
| 10 | `workloads/stages` | `create_stage_s3.tfvars` | Schemas (step 7), storage integrations (step 6) |
| 11 | `platform/network_policies` | `create_network_policies.tfvars` | None |
| 12 | `platform/account_parameters` | `create_account_parameters.tfvars` | None |
| 13 | `account_governance/service_users` | `create_service_users.tfvars` | Roles (step 1) |

## Standard Plan Command
```bash
bash scripts/stack-plan.sh <env> <layer> <resource> --run
```

Never use raw `terraform plan` — missing `-var-file` flags cause Terraform to use empty defaults and destroy all resources. `stack-plan.sh` enforces correct flag injection and pre-flight checks on every run.

## Provider Alias Ownership
- `secadmin` → roles, users, service users, network rules
- `sysadmin` → databases, warehouses, schemas, stages
- `accountadmin` → resource monitors, storage integrations, external access integrations, network policies, account parameters

## Environment Naming
- `*_TEST` in `test`
- `*_STAGE` in `stage`
- No suffix in `prod`

## SnowSQL Escape Hatches
Operations NOT supported by the Terraform provider — route to SnowSQL:
- Database renames → `live/<env>/platform/database_rename/`
- External access integrations → `live/<env>/platform/external_access_integrations/`
