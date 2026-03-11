locals {
  warehouse_outputs = var.enable_warehouse && length(module.warehouse) > 0 ? module.warehouse[0].warehouse_names : {}
}

output "warehouse_names" {
  value       = local.warehouse_outputs
  description = "Map of warehouse names managed by this stack."
}

output "warehouse_name" {
  value = length(local.warehouse_outputs) == 0 ? null : (
    var.warehouse_name != null && try(trimspace(var.warehouse_name), "") != "" && try(contains(keys(local.warehouse_outputs), trimspace(var.warehouse_name)), false)
      ? local.warehouse_outputs[trimspace(var.warehouse_name)]
      : values(local.warehouse_outputs)[0]
  )
  description = "Legacy single warehouse name for backwards compatibility."
}
