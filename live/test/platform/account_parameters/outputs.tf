output "account_parameter_keys" {
  value       = var.enable_account_parameters && length(module.account_parameters) > 0 ? module.account_parameters[0].account_parameter_keys : {}
  description = "Map of account parameter keys managed by this stack."
}
