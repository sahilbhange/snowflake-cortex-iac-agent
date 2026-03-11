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

## User — Service Account (RSA key auth)
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

## Snow CLI
```bash
snow sql -c sf_int
snow sql -c sf_int -f file.sql --format JSON > result.json
```
