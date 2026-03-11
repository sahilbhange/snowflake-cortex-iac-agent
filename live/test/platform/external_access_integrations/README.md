# External Access Integrations Stack

Usage
- Define configs for stages  
  - [create_external_access_integrations.tfvars](../../configs/create_external_access_integrations.tfvars)
  
- `cd live/test/platform/external_access_integrations`
- `terraform init -upgrade`
- Plan/apply with shared connection vars and the integration config:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_external_access_integrations.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_external_access_integrations.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path` (optional), `query_tag` (default `terraform`), `accountadmin_role` (default `ACCOUNTADMIN`), `snowsql_connection` (optional)
- Integrations: `external_access_integrations` map (key = integration name) specifying allowed/blocked network or API integrations, enabled flag, optional comment. Legacy single integration variables remain available.

Notes

- Creating external access integrations requires ACCOUNTADMIN privileges; the `providers.tf` scaffolding is ready for native resources once the Snowflake provider exposes them.
- Ensure referenced network rules already exist (for example via the `platform/network_rules` stack).
- Requires `snowsql` configured via environment (the stack uses local-exec today, passes `snowsql_connection` to `snowsql -c`, and enables `exit_on_error` so Terraform fails when the SQL fails).
- Create a connection with default role ACCOUNTADMIN for this config (example SnowSQL profile):
    [connections.sample_admin]
    organization_name = "<your_organization>"
    accountname = "<your_account_locator>"
    username = "<provisioning_user>"
    private_key_path = "C:\\path\\to\\.snowflake\\rsa_key.p8"

    # (Optional) default DB, schema, warehouse, role:
    dbname = "<optional_default_db>"
    schemaname = "<optional_default_schema>"
    warehousename = "<optional_default_wh>"
    rolename = accountadmin   --- Required to create external access integration

