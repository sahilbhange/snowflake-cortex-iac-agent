locals {
  network_rule_outputs = var.enable_network_rules && length(module.network_rules) > 0 ? module.network_rules[0].network_rule_full_names : {}
}

output "network_rule_full_names" {
  value       = local.network_rule_outputs
  description = "Map of fully qualified network rule names managed by this stack."
}

output "network_rule_name" {
  value = length(local.network_rule_outputs) == 0 ? null : (
    var.network_rule_name != null && try(trimspace(var.network_rule_name), "") != "" && try(contains(keys(local.network_rule_outputs), trimspace(var.network_rule_name)), false)
    ? local.network_rule_outputs[trimspace(var.network_rule_name)]
    : values(local.network_rule_outputs)[0]
  )
  description = "Legacy single network rule output."
}
