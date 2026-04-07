variable "organization_name" {
  type = string
}

variable "account_name" {
  type = string
}

variable "provisioning_user" {
  type = string
}

variable "private_key_path" {
  type = string
}

variable "private_key_passphrase" {
  type        = string
  description = "Passphrase for encrypted private key, if applicable."
  default     = null
}

variable "query_tag" {
  type        = string
  description = "Query tag applied to Snowflake sessions created by Terraform."
  default     = "terraform"
}

variable "accountadmin_role" {
  type    = string
  default = "ACCOUNTADMIN"
}

variable "enable_network_policies" {
  type    = bool
  default = true
}

variable "network_policies" {
  description = "Map of network policies to manage (key = policy name)."
  type = map(object({
    allowed_ip_list           = optional(list(string), [])
    blocked_ip_list           = optional(list(string), [])
    allowed_network_rule_list = optional(list(string), [])
    blocked_network_rule_list = optional(list(string), [])
    comment                   = optional(string)
  }))
  default = {}
}

variable "network_policy_name" {
  type    = string
  default = null
}

variable "network_policy_allowed_ip_list" {
  type    = list(string)
  default = []
}

variable "network_policy_blocked_ip_list" {
  type    = list(string)
  default = []
}

variable "network_policy_allowed_network_rule_list" {
  type    = list(string)
  default = []
}

variable "network_policy_blocked_network_rule_list" {
  type    = list(string)
  default = []
}

variable "network_policy_comment" {
  type    = string
  default = null
}
