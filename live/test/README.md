# Test Environment Terraform Layout

This environment now follows a split-stack approach aligned to common Snowflake operating models:

- **Account Governance** - security-admin scope (roles, users, network policies, etc.).
- **Platform** - shared infrastructure (databases, warehouses, resource monitors, storage integrations).
- **Workloads & Data Products** - application- or domain-specific objects (schemas, stages, future tasks).

Each stack keeps its own Terraform state. Run commands from inside the desired subdirectory and pass the shared account variables stored one level up.

```
live/test/
|- account_governance/
|  |- roles/
|  \- users/
|- platform/
|  |- databases/
|  |- warehouses/
|  |- resource_monitors/
|  \- storage_integrations_s3/
\- workloads/
   |- schemas/
   \- stages/
```

## Shared account configuration

Edit `live/test/account.auto.tfvars` once with connection details and role aliases:

```hcl
organization_name = "example_org"
account_name      = "example_account"
provisioning_user = "terraform_user"
private_key_path  = "~/.snowflake/terraform_user_key.p8"
securityadmin_role = "SECURITYADMIN"
sysadmin_role      = "SYSADMIN"
accountadmin_role  = "ACCOUNTADMIN"
query_tag          = "terraform"
```

## Stack runbook

| Category             | Directory                                      | Typical command                                                                 |
|----------------------|------------------------------------------------|----------------------------------------------------------------------------------|
| Account Governance   | `live/test/account_governance/roles`           | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_role.tfvars` |
|                      | `live/test/account_governance/users`           | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_users.tfvars` |
| Platform             | `live/test/platform/databases`                 | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_database.tfvars` |
|                      | `live/test/platform/warehouses`                | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_warehouse.tfvars` |
|                      | `live/test/platform/resource_monitors`         | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_resource_monitor.tfvars` |
|                      | `live/test/platform/storage_integrations_s3`   | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_storage_integration_s3.tfvars` |
|                      | `live/test/platform/database_rename`           | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/rename_database.tfvars.json` |
| Workloads/Data Prod. | `live/test/workloads/schemas`                  | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_schema.tfvars` |
|                      | `live/test/workloads/stages`                   | `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_stage_s3.tfvars` |

Add `terraform apply ... -auto-approve` (or omit `-auto-approve`) using the same variable files when ready to provision.

## Special processing

- `live/test/platform/database_rename` shells out to SnowSQL to perform the actual rename before you reconcile Terraform state (see the dedicated `README.md` and `RENAMING_LIMITATIONS.md` in that directory).
- `live/test/platform/external_access_integrations` invokes SnowSQL via `local-exec` to create integrations until native Terraform resources catch up; configure a SnowSQL connection profile before running it.

## Remote state (recommended)

Each stack currently writes local state. For team use, configure a remote backend (S3 + DynamoDB, Terraform Cloud, etc.) per directory. Example snippet for S3:

```hcl
terraform {
  backend "s3" {
    bucket         = "tf-state"
    key            = "snowflake/test/platform/databases/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-state-locks"
    encrypt        = true
  }
}
```

## Cross-stack coordination

- Use stable naming (e.g., database names, role names) so workloads can reference platform resources via variables.
- When cross-stack outputs are needed, export them via `outputs.tf` in the producing stack and consume via `terraform_remote_state` in the caller.
- Apply `lifecycle { prevent_destroy = true }` in stacks managing critical primitives to avoid accidental removal.

