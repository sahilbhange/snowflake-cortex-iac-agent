
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

# Accept legacy toggle from shared tfvars (unused in this stack)
variable "enable_database" {
  type    = bool
  default = true
}

# Database inputs
variable "databases" {
  description = "Map of databases to manage (key = database name)."
  type = map(object({
    comment                     = optional(string)
    data_retention_time_in_days = optional(number)
  }))
  default = {}
}

variable "database_name" {
  type    = string
  default = null
}
variable "database_comment" {
  type    = string
  default = null
}
variable "database_data_retention_days" {
  type    = number
  default = 1
}
