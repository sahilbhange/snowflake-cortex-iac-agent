locals {
  explicit_databases = {
    for name, cfg in var.databases : trimspace(name) => {
      comment                     = try(cfg.comment, null)
      data_retention_time_in_days = try(cfg.data_retention_time_in_days, 1)
    }
    if trimspace(name) != ""
  }

  legacy_database = var.database_name == null ? {} : {
    trimspace(var.database_name) = {
      comment                     = var.database_comment
      data_retention_time_in_days = var.database_data_retention_days
    }
  }

  resolved_databases = length(var.databases) > 0 ? local.explicit_databases : local.legacy_database
}

module "database" {
  for_each  = var.enable_database ? local.resolved_databases : {}
  source    = "../../../../modules/databases"
  providers = { snowflake = snowflake.sysadmin }

  name                        = each.key
  comment                     = each.value.comment
  data_retention_time_in_days = each.value.data_retention_time_in_days
}
