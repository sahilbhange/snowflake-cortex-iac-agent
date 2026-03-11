variable "warehouses" {
  description = "Map of warehouses to manage (key = warehouse name)."
  type = map(object({
    size              = optional(string)
    auto_suspend      = optional(number)
    auto_resume       = optional(bool)
    min_cluster_count = optional(number)
    max_cluster_count = optional(number)
    comment           = optional(string)
  }))
  default = {}
}

variable "name" {
  type     = string
  default  = null
  nullable = true
}

variable "size" {
  type     = string
  default  = null
  nullable = true
}

variable "auto_suspend" {
  type     = number
  default  = null
  nullable = true
}

variable "auto_resume" {
  type     = bool
  default  = null
  nullable = true
}

variable "min_cluster_count" {
  type     = number
  default  = null
  nullable = true
}

variable "max_cluster_count" {
  type     = number
  default  = null
  nullable = true
}

variable "comment" {
  type     = string
  default  = null
  nullable = true
}

locals {
  default_size              = coalesce(var.size, "XSMALL")
  default_auto_suspend      = coalesce(var.auto_suspend, 300)
  default_auto_resume       = coalesce(var.auto_resume, true)
  default_min_cluster_count = coalesce(var.min_cluster_count, 1)
  default_max_cluster_count = coalesce(var.max_cluster_count, 1)

  explicit_warehouses = {
    for warehouse_name, cfg in var.warehouses : trimspace(warehouse_name) => {
      size              = coalesce(try(cfg.size, null), local.default_size)
      auto_suspend      = coalesce(try(cfg.auto_suspend, null), local.default_auto_suspend)
      auto_resume       = coalesce(try(cfg.auto_resume, null), local.default_auto_resume)
      min_cluster_count = coalesce(try(cfg.min_cluster_count, null), local.default_min_cluster_count)
      max_cluster_count = coalesce(try(cfg.max_cluster_count, null), local.default_max_cluster_count)
      comment           = try(cfg.comment, var.comment)
    }
    if trimspace(warehouse_name) != ""
  }

  legacy_warehouse = (
    var.name == null || try(trimspace(var.name), "") == "" ? {} : {
      trimspace(var.name) = {
        size              = local.default_size
        auto_suspend      = local.default_auto_suspend
        auto_resume       = local.default_auto_resume
        min_cluster_count = local.default_min_cluster_count
        max_cluster_count = local.default_max_cluster_count
        comment           = var.comment
      }
    }
  )

  resolved_warehouses = length(local.explicit_warehouses) > 0 ? local.explicit_warehouses : local.legacy_warehouse
}

resource "snowflake_warehouse" "this" {
  for_each = local.resolved_warehouses

  name              = each.key
  warehouse_size    = each.value.size
  auto_suspend      = each.value.auto_suspend
  auto_resume       = each.value.auto_resume
  min_cluster_count = each.value.min_cluster_count
  max_cluster_count = each.value.max_cluster_count
  comment           = each.value.comment
}

output "warehouse_names" {
  value       = { for warehouse_name, warehouse in snowflake_warehouse.this : warehouse_name => warehouse.name }
  description = "Map of Snowflake warehouse names managed by this module."
}

output "warehouse_name" {
  value = length(snowflake_warehouse.this) == 0 ? null : (
    var.name != null && try(trimspace(var.name), "") != "" && try(contains(keys(snowflake_warehouse.this), trimspace(var.name)), false)
    ? snowflake_warehouse.this[trimspace(var.name)].name
    : values(snowflake_warehouse.this)[0].name
  )
  description = "Legacy single warehouse name output for backwards compatibility."
}
