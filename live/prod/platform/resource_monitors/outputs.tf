locals {
  resource_monitor_names = try(module.resource_monitor[0].resource_monitor_names, {})
}

output "resource_monitor_names" {
  value       = local.resource_monitor_names
  description = "Map of resource monitor names managed by this stack."
}

output "resource_monitor_name" {
  value = try(
    (
      var.rm_name != null && var.rm_name != "" && contains(keys(local.resource_monitor_names), var.rm_name)
    ) ? local.resource_monitor_names[var.rm_name] : values(local.resource_monitor_names)[0],
    null
  )
  description = "Legacy single resource monitor name for backwards compatibility."
}
