
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

variable "securityadmin_role" {
  type    = string
  default = "SECURITYADMIN"
}

variable "sysadmin_role" {
  type    = string
  default = "SYSADMIN"
}

# Accept legacy toggle from shared tfvars (unused in this stack)
variable "enable_users" {
  type    = bool
  default = true
}

# Users input (mirrors live/test/variables.tf)
variable "users" {
  description = "Map of users to create. Key is user name."
  type = map(object({
    login_name                             = optional(string)
    first_name                             = optional(string)
    last_name                              = optional(string)
    email                                  = optional(string)
    disabled                               = optional(bool, false)
    default_role                           = optional(string)
    default_warehouse                      = optional(string)
    must_change_password                   = optional(bool, false)
    rsa_public_key                         = optional(string)
    comment                                = optional(string)
    display_name                           = optional(string)
    roles                                  = optional(list(string), [])
    workspace_schema_name                  = optional(string)
    workspace_schema_additional_privileges = optional(list(string), [])
    create_workspace_schema                = optional(bool, true)
  }))
  default = {}
}

variable "workspace_schema_database" {
  type        = string
  default     = null
  description = "Database where per-user workspace schemas will be created."
}

variable "workspace_schema_comment" {
  type        = string
  default     = null
  description = "Optional comment to apply to each per-user workspace schema."
}

variable "workspace_schema_grant_roles" {
  type        = list(string)
  default     = []
  description = "Roles that receive privileges on the per-user workspace schemas."
}

variable "workspace_schema_grant_privileges" {
  type        = list(string)
  default     = []
  description = "Privileges granted to workspace_schema_grant_roles on each workspace schema."
}
