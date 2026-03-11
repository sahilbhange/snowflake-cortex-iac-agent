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
  type     = string
  default  = null
  nullable = true
}

variable "private_key_passphrase" {
  type        = string
  description = "Passphrase for encrypted private key, if applicable."
  default     = null
}

variable "query_tag" {
  description = "Query tag applied to Snowflake sessions created by Terraform."
  type        = string
  default     = "terraform"
}

variable "accountadmin_role" {
  type    = string
  default = "ACCOUNTADMIN"
}

variable "snowsql_connection" {
  description = "Optional SnowSQL connection profile name to use for local-exec commands until native resources are available."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_external_access_integrations" {
  type    = bool
  default = true
}

variable "external_access_integrations" {
  description = "Map of external access integrations to manage (key = integration name)."
  type = map(object({
    enabled                  = optional(bool)
    allowed_network_rules    = optional(list(string))
    blocked_network_rules    = optional(list(string))
    allowed_api_integrations = optional(list(string))
    blocked_api_integrations = optional(list(string))
    comment                  = optional(string)
  }))
  default = {}
}

variable "integration_name" {
  type    = string
  default = null
}

variable "integration_enabled" {
  type    = bool
  default = null
}

variable "integration_allowed_network_rules" {
  type    = list(string)
  default = []
}

variable "integration_blocked_network_rules" {
  type    = list(string)
  default = []
}

variable "integration_allowed_api_integrations" {
  type    = list(string)
  default = []
}

variable "integration_blocked_api_integrations" {
  type    = list(string)
  default = []
}

variable "integration_comment" {
  type    = string
  default = null
}
