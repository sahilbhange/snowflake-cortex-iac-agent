locals {
  schema_fqn_map = { for name, mod in module.schema : name => mod.schema_fqn }
}

output "schema_fqns" {
  value       = local.schema_fqn_map
  description = "Map of schema FQNs managed by this stack."
}

output "schema_fqn" {
  value = try(
    (
      var.schema_name != null && var.schema_name != "" && contains(keys(local.schema_fqn_map), var.schema_name)
    ) ? local.schema_fqn_map[var.schema_name] : values(local.schema_fqn_map)[0],
    null
  )
  description = "Legacy single schema output. Uses schema_name when set, otherwise returns the first managed schema (if any)."
}
