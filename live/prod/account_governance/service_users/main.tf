module "service_users" {
  count  = var.enable_service_users ? 1 : 0
  source = "../../../../modules/service_users"
  providers = {
    snowflake = snowflake.secadmin
  }

  service_users = var.service_users
}
