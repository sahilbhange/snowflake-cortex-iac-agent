variable "organization_name" {
  type        = string
  description = "Snowflake organization name used by the provider."
}

variable "account_name" {
  type        = string
  description = "Snowflake account name used by the provider."
}

variable "provisioning_user" {
  type        = string
  description = "User leveraged by Terraform/SnowSQL connections."
}

variable "private_key_path" {
  type        = string
  description = "Path to the private key for the provisioning user."
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

variable "sysadmin_role" {
  type        = string
  description = "Role used for the Snowflake provider to perform verification lookups."
  default     = "SYSADMIN"
}

variable "default_snowsql_connection" {
  type        = string
  description = "Default Snow CLI connection profile name to use when a request does not supply one."
  default     = null
}

variable "rename_requests" {
  description = <<EOT
Map of rename requests keyed by an operator-friendly identifier.
Each request expects the existing database name (`from`) and the desired name (`to`).
Optional attributes:
  * `snowsql_connection` - Snow CLI connection profile to use for this rename.
  * `state_from_key`     - Existing Terraform `for_each` key; defaults to `from`.
  * `state_to_key`       - Replacement Terraform `for_each` key; defaults to `to`.
  * `module_address`     - Terraform module address that owns the database state; defaults to `module.database`.
  * `execute`            - If false, the request is ignored (useful for staging rename plans).
EOT
  type = map(object({
    from               = string
    to                 = string
    snowsql_connection = optional(string)
    state_from_key     = optional(string)
    state_to_key       = optional(string)
    module_address     = optional(string)
    execute            = optional(bool, true)
  }))
  default = {}
}
