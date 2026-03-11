locals {
  legacy_warehouse = (
    var.warehouse_name == null || try(trimspace(var.warehouse_name), "") == "" ? {} : {
      trimspace(var.warehouse_name) = {
        size               = var.warehouse_size
        auto_suspend       = var.warehouse_auto_suspend
        auto_resume        = var.warehouse_auto_resume
        min_cluster_count  = var.warehouse_min_cluster_count
        max_cluster_count  = var.warehouse_max_cluster_count
        comment            = var.warehouse_comment
      }
    }
  )

  resolved_warehouses = length(var.warehouses) > 0 ? var.warehouses : local.legacy_warehouse
}

module "warehouse" {
  count     = var.enable_warehouse ? 1 : 0
  source    = "../../../../modules/warehouses"
  providers = { snowflake = snowflake.sysadmin }

  warehouses          = { for name, cfg in local.resolved_warehouses : trimspace(name) => cfg }
  name                = var.warehouse_name
  size                = var.warehouse_size
  auto_suspend        = var.warehouse_auto_suspend
  auto_resume         = var.warehouse_auto_resume
  min_cluster_count   = var.warehouse_min_cluster_count
  max_cluster_count   = var.warehouse_max_cluster_count
  comment             = var.warehouse_comment
}
