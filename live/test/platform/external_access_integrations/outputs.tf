locals {
  integration_names = var.enable_external_access_integrations && length(module.external_access_integrations) > 0 ? module.external_access_integrations[0].external_access_integration_names : []
}

output "external_access_integration_names" {
  value       = local.integration_names
  description = "List of external access integration names managed by this stack."
}

output "external_access_integration_name" {
  value = length(local.integration_names) == 0 ? null : (
    var.integration_name != null && try(trimspace(var.integration_name), "") != "" && try(contains(local.integration_names, trimspace(var.integration_name)), false)
      ? trimspace(var.integration_name)
      : local.integration_names[0]
  )
  description = "Legacy single integration name."
}
