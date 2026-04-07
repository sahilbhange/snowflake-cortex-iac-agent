variable "account_parameters" {
  description = "Map of account parameters to set (key = parameter name, value = parameter value as string)."
  type        = map(string)
  default     = {}
}

resource "snowflake_account_parameter" "this" {
  for_each = var.account_parameters

  key   = upper(each.key)
  value = each.value
}

output "account_parameter_keys" {
  value       = { for k, v in snowflake_account_parameter.this : k => v.key }
  description = "Map of account parameter keys managed by this module."
}
