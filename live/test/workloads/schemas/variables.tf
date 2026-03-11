
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

variable "sysadmin_role" {
  type    = string
  default = "SYSADMIN"
}

variable "enable_schema" {
  type    = bool
  default = true
}

variable "schema_database" {
  type = string
  default = null

}

variable "schemas" {
  description = "Map of schemas to manage (key = schema name)."
  type = map(object({
    database = optional(string)
    comment  = optional(string)
  }))
  default = {}
}

variable "schema_name" {
  type    = string
  default = null
}

variable "schema_comment" {
  type    = string
  default = null
}
