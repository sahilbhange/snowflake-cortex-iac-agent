locals {
  network_policy_outputs = var.enable_network_policies && length(module.network_policies) > 0 ? module.network_policies[0].network_policy_names : {}
}

output "network_policy_names" {
  value       = local.network_policy_outputs
  description = "Map of network policy names managed by this stack."
}

output "network_policy_name" {
  value = length(local.network_policy_outputs) == 0 ? null : (
    var.network_policy_name != null && try(trimspace(var.network_policy_name), "") != "" && try(contains(keys(local.network_policy_outputs), trimspace(var.network_policy_name)), false)
    ? local.network_policy_outputs[trimspace(var.network_policy_name)]
    : values(local.network_policy_outputs)[0]
  )
  description = "Legacy single network policy output."
}
