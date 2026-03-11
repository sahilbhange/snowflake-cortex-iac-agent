locals {
  snowflake_provider_private_key = (
    var.private_key_path == null || trimspace(var.private_key_path) == ""
    ? null
    : file(var.private_key_path)
  )

  snowflake_provider_params = (
    var.query_tag == null || trimspace(var.query_tag) == ""
    ? {}
    : { QUERY_TAG = trimspace(var.query_tag) }
  )
}

provider "snowflake" {
  alias             = "accountadmin"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.provisioning_user
  role              = var.accountadmin_role
  params            = local.snowflake_provider_params
  authenticator     = local.snowflake_provider_private_key == null ? null : "SNOWFLAKE_JWT"
  private_key            = local.snowflake_provider_private_key
  private_key_passphrase = var.private_key_passphrase
}

