locals {
  database_name_map = { for name, mod in module.database : name => mod.database_name }
}

output "database_names" {
  value       = local.database_name_map
  description = "Map of database names managed by this stack."
}

output "database_name" {
  value = try(
    (
      var.database_name != null && var.database_name != "" && contains(keys(local.database_name_map), var.database_name)
    ) ? local.database_name_map[var.database_name] : values(local.database_name_map)[0],
    null
  )
  description = "Legacy single database output. Uses database_name when set, otherwise returns the first managed database (if any)."
}
