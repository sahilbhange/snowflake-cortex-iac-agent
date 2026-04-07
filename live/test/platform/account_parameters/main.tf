module "account_parameters" {
  count     = var.enable_account_parameters ? 1 : 0
  source    = "../../../../modules/account_parameters"
  providers = { snowflake = snowflake.accountadmin }

  account_parameters = var.account_parameters
}
