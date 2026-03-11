provider "snowflake" {
  alias             = "accountadmin"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.provisioning_user
  authenticator     = "SNOWFLAKE_JWT"
  private_key            = file(var.private_key_path)
  private_key_passphrase = var.private_key_passphrase
  params = {
    QUERY_TAG = var.query_tag
  }
  preview_features_enabled = ["snowflake_network_rule_resource"]
  role = var.accountadmin_role
}
