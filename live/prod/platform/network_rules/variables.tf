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

variable "enable_network_rules" {
  type    = bool
  default = true
}

variable "network_rules" {
  description = "Map of network rules to manage (key = rule name)."
  type = map(object({
    database    = string
    schema      = string
    type        = string
    mode        = string
    value_list  = list(string)
    comment     = optional(string)
  }))
  default = {}
}

variable "network_rule_name" {
  type    = string
  default = null
}

variable "network_rule_database" {
  type    = string
  default = null
}

variable "network_rule_schema" {
  type    = string
  default = null
}

variable "network_rule_type" {
  type    = string
  default = null
}

variable "network_rule_mode" {
  type    = string
  default = null
}

variable "network_rule_value_list" {
  type    = list(string)
  default = []
}

variable "network_rule_comment" {
  type    = string
  default = null
}
