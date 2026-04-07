# HCL Patterns — v2.x Provider Reference

Use these blocks as copy-paste templates. All resource names follow snake_case; all Snowflake object names UPPERCASE.

## Provider Block
```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.14"
    }
  }
}

provider "snowflake" { alias = "secadmin";    role = "SECURITYADMIN" }
provider "snowflake" { alias = "sysadmin";     role = "SYSADMIN" }
provider "snowflake" { alias = "accountadmin"; role = "ACCOUNTADMIN" }
```

## Role
```hcl
resource "snowflake_account_role" "analyst_role" {
  provider = snowflake.secadmin
  name     = "ANALYST_ROLE"
  comment  = "Role for analytics squad"
  lifecycle { prevent_destroy = true }
}
```

## Role Hierarchy (parent to SYSADMIN)
```hcl
resource "snowflake_grant_account_role" "analyst_to_sysadmin" {
  provider         = snowflake.secadmin
  role_name        = snowflake_account_role.analyst_role.name
  parent_role_name = "SYSADMIN"
}
```

## Grant Role to User
```hcl
resource "snowflake_grant_account_role" "grant_analyst_to_user" {
  provider  = snowflake.secadmin
  role_name = snowflake_account_role.analyst_role.name
  user_name = snowflake_user.john_doe.name
}
```

## Grant on Account Object (Database or Warehouse)
```hcl
resource "snowflake_grant_privileges_to_account_role" "analyst_db_usage" {
  provider          = snowflake.secadmin
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"   # or "WAREHOUSE"
    object_name = snowflake_database.analytics_db.name
  }
}
```

## Grant on All Schemas in Database
```hcl
resource "snowflake_grant_privileges_to_account_role" "analyst_schema_usage" {
  provider          = snowflake.secadmin
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE"]
  on_schema {
    all_schemas_in_database = snowflake_database.analytics_db.name
  }
}
```

## Grant on Future Schemas
```hcl
resource "snowflake_grant_privileges_to_account_role" "analyst_future_schemas" {
  provider          = snowflake.secadmin
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE"]
  on_schema {
    future_schemas_in_database = snowflake_database.analytics_db.name
  }
}
```

## Grant SELECT on All Tables in Database
```hcl
resource "snowflake_grant_privileges_to_account_role" "analyst_table_select" {
  provider          = snowflake.secadmin
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["SELECT"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_database        = snowflake_database.analytics_db.name
    }
  }
}
```

## Grant SELECT on Future Tables
```hcl
resource "snowflake_grant_privileges_to_account_role" "analyst_future_tables" {
  provider          = snowflake.secadmin
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_database        = snowflake_database.analytics_db.name
    }
  }
}
```

## Warehouse
```hcl
resource "snowflake_warehouse" "analyst_wh" {
  provider       = snowflake.sysadmin
  name           = "ANALYST_WH"
  warehouse_size = "XSMALL"
  auto_suspend   = 60
  auto_resume    = true
  comment        = "Warehouse for analytics squad"
}
```

## Database
```hcl
resource "snowflake_database" "analytics_db" {
  provider = snowflake.sysadmin
  name     = "ANALYTICS_DB"
  comment  = "Transformed and modeled data"
  lifecycle { prevent_destroy = true }
}
```

## Schema
```hcl
resource "snowflake_schema" "mart_schema" {
  provider = snowflake.sysadmin
  name     = "MART_SCHEMA"
  database = snowflake_database.analytics_db.name
  comment  = "Presentation layer for BI tools"
}
```

## User — Human (password auth)
```hcl
resource "snowflake_user" "john_doe" {
  provider             = snowflake.secadmin
  name                 = "JOHN_DOE"
  login_name           = "john.doe"
  email                = "john.doe@company.com"
  display_name         = "John Doe"
  default_role         = snowflake_account_role.analyst_role.name
  default_warehouse    = snowflake_warehouse.analyst_wh.name
  must_change_password = true
}
```

## User — Service Account (RSA key auth) — LEGACY
> **Prefer `snowflake_service_user` below for new service accounts.**
> This pattern uses `snowflake_user` which creates a LEGACY-type user. It still works
> but does not enforce TYPE=SERVICE at the Snowflake level.
```hcl
resource "snowflake_user" "terraform_svc" {
  provider          = snowflake.secadmin
  name              = "TERRAFORM_SVC"
  login_name        = "terraform_svc"
  comment           = "Terraform provisioning service account"
  rsa_public_key    = file("${path.module}/keys/terraform_svc.pub")
  default_role      = snowflake_account_role.ci_role.name
  default_warehouse = snowflake_warehouse.ci_wh.name
}
```

## Service User (TYPE=SERVICE) — v2.x
Uses `snowflake_service_user` (provider v2.14+). Enforces TYPE=SERVICE at Snowflake
level — no password, no interactive login, key-pair auth only.
- **Provider**: `secadmin`
- **Stack**: `account_governance/service_users`
- **Config**: `create_service_users.tfvars`
```hcl
resource "snowflake_service_user" "dbt_svc" {
  provider          = snowflake.secadmin
  name              = "DBT_SVC"
  login_name        = "dbt_svc"
  display_name      = "dbt Service Account"
  disabled          = false
  default_role      = "DBT_ROLE"
  default_warehouse = "DBT_WH"
  rsa_public_key    = "MIIBIjANBg..."   # managed outside Terraform
  rsa_public_key_2  = null
  comment           = "dbt Cloud service account — key-pair auth only"

  lifecycle { ignore_changes = [rsa_public_key, rsa_public_key_2] }
}

resource "snowflake_grant_account_role" "dbt_svc_roles" {
  provider  = snowflake.secadmin
  role_name = "DBT_ROLE"
  user_name = snowflake_service_user.dbt_svc.name
}
```

### Service User tfvars pattern
```hcl
service_users = {
  DBT_SVC = {
    login_name        = "dbt_svc"
    display_name      = "dbt Service Account"
    disabled          = false
    default_role      = "DBT_ROLE"
    default_warehouse = "DBT_WH"
    rsa_public_key    = "MIIBIjANBg..."
    rsa_public_key_2  = null
    comment           = "dbt Cloud service account"
    granted_roles     = ["DBT_ROLE"]
  }
}
```

## Network Policy
Uses `snowflake_network_policy` (provider v2.x). Controls inbound IP access at
account or user level.
- **Provider**: `accountadmin`
- **Stack**: `platform/network_policies`
- **Config**: `create_network_policies.tfvars`
```hcl
resource "snowflake_network_policy" "account_policy" {
  provider = snowflake.accountadmin
  name     = "ACCOUNT_NETWORK_POLICY"

  allowed_ip_list    = ["203.0.113.0/24", "198.51.100.0/24"]
  blocked_ip_list    = ["203.0.113.50/32"]
  allowed_network_rule_list = []
  blocked_network_rule_list = []

  comment = "Account-level network policy — controls inbound access"
}
```

### Network Policy tfvars pattern
```hcl
network_policies = {
  ACCOUNT_NETWORK_POLICY = {
    allowed_ip_list = ["203.0.113.0/24", "198.51.100.0/24"]
    blocked_ip_list = ["203.0.113.50/32"]
    comment         = "Account-level network policy"
  }
}
```

## Account Parameter
Uses `snowflake_account_parameter` (provider v2.x). Sets account-level configuration.
- **Provider**: `accountadmin`
- **Stack**: `platform/account_parameters`
- **Config**: `create_account_parameters.tfvars`
```hcl
resource "snowflake_account_parameter" "stmt_timeout" {
  provider = snowflake.accountadmin
  key      = "STATEMENT_TIMEOUT_IN_SECONDS"
  value    = "3600"
}
```

### Account Parameter tfvars pattern
```hcl
account_parameters = {
  STATEMENT_TIMEOUT_IN_SECONDS           = "3600"
  TIMEZONE                               = "America/New_York"
  DATA_RETENTION_TIME_IN_DAYS            = "1"
  PERIODIC_DATA_REKEYING                 = "false"
  ENABLE_TRI_SECRET_NET                  = "false"
  REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = "true"
}
```

## Critical: One Grant Block Per Role Per Object Type
```hcl
# CORRECT — all DB-level privileges in one block
resource "snowflake_grant_privileges_to_account_role" "analyst_db" {
  account_role_name = snowflake_account_role.analyst_role.name
  privileges        = ["USAGE", "MONITOR"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.analytics_db.name
  }
}

# WRONG — two blocks for same role = perpetual drift + destroy risk
# resource "snowflake_grant_privileges_to_account_role" "analyst_db_1" { ... }
# resource "snowflake_grant_privileges_to_account_role" "analyst_db_2" { ... }
```

## Known v2.x Behaviors
- Multiple grant blocks for same role → perpetual plan drift
- `snowflake_user.login_name` is ForceNew — warn before changing
- `snowflake_schema.with_managed_access` change → ForceNew — HIGH RISK
- Grant resources may show a plan on first apply — expected
- `snowflake_service_user` — TYPE=SERVICE enforced; no password allowed; key-pair only
- `snowflake_network_policy` — removing a policy assigned to the account locks everyone out; always validate allowed_ip_list first
- `snowflake_account_parameter` — key is uppercased automatically; value is always a string

## Snow CLI
```bash
snow sql -c sf_int
snow sql -c sf_int -f file.sql --format JSON > result.json
```
