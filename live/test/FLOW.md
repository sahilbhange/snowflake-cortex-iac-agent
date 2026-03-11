# FLOW — test env

## Stack execution order

Apply in this sequence — later stacks depend on earlier ones:

1. `account_governance/roles`
2. `platform/databases`          ← before users; WORKSPACE_DB must exist for workspace schemas
3. `account_governance/users`
4. `platform/warehouses`
5. `platform/resource_monitors`
6. `platform/storage_integrations_s3` (SnowSQL)
7. `workloads/schemas` ← before network_rules; creates ADMIN_DB.GOVERNANCE
8. `platform/network_rules`
9. `platform/external_access_integrations` (SnowSQL)
10. `workloads/stages`

## Rules

- **Provider aliases**: `secadmin` for roles/users/network rules; `sysadmin` for databases/warehouses/schemas/stages; `accountadmin` for storage integrations/resource monitors/external access integrations.
- **One task at a time**: each `configs/*.tfvars` toggles exactly one module (e.g., `enable_users = true`).
- **Bulk only for users**: pass a `users` map to create many users in one apply.
