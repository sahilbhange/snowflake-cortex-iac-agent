locals {
  role_name_list = keys(module.role)
}

output "role_names" {
  value       = local.role_name_list
  description = "List of Snowflake roles managed by this stack."
}

output "role_name" {
  value = length(local.role_name_list) == 0 ? null : (
    var.role_name != null && var.role_name != "" && try(contains(local.role_name_list, var.role_name), false)
      ? var.role_name
      : local.role_name_list[0]
  )
  description = "Legacy single role output. Uses role_name when set, otherwise returns the first managed role (if any)."
}
