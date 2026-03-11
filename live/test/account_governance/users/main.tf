module "users" {
  source    = "../../../../modules/users"
  providers = {
    snowflake          = snowflake.secadmin
    snowflake.sysadmin = snowflake.sysadmin
  }

  users                             = var.users
  workspace_schema_database         = var.workspace_schema_database
  workspace_schema_comment          = var.workspace_schema_comment
  workspace_schema_grant_roles      = var.workspace_schema_grant_roles
  workspace_schema_grant_privileges = var.workspace_schema_grant_privileges
}
