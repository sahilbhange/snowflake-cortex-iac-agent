locals {
  explicit_resource_monitors = {
    for name, cfg in var.resource_monitors : trimspace(name) => {
      credit_quota    = cfg.credit_quota
      frequency       = try(cfg.frequency, null)
      start_timestamp = try(cfg.start_timestamp, null)
    }
    if trimspace(name) != ""
  }

  legacy_resource_monitor = var.rm_name == null ? {} : {
    trimspace(var.rm_name) = {
      credit_quota    = var.rm_credit_quota
      frequency       = var.rm_frequency
      start_timestamp = var.rm_start_timestamp
    }
  }

  resolved_resource_monitors = length(var.resource_monitors) > 0 ? local.explicit_resource_monitors : local.legacy_resource_monitor
}

module "resource_monitor" {
  count     = var.enable_resource_monitor ? 1 : 0
  source    = "../../../../modules/resource_monitors"
  providers = { snowflake = snowflake.accountadmin }

  resource_monitors = local.resolved_resource_monitors
  name              = var.rm_name
  credit_quota      = var.rm_credit_quota
  frequency         = var.rm_frequency
  start_timestamp   = var.rm_start_timestamp
}
