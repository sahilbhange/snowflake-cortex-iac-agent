variable "private_key_passphrase" {
  type        = string
  description = "Passphrase for encrypted private key, if applicable."
  default     = null
}

# variable "private_key_pem" {
#   type = string
#   description = "PEM contents for key-pair auth. If null, falls back to private_key_path."
# }

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

variable "query_tag" {
  type        = string
  description = "Query tag applied to Snowflake sessions created by Terraform."
  default     = "terraform"
}

variable "securityadmin_role" {
  type    = string
  default = "SECURITYADMIN"
}

# Accept legacy toggle from shared tfvars (unused in this stack)
variable "enable_role" {
  type    = bool
  default = true
}

# Role inputs
variable "roles" {
  description = "Map of roles to manage (key = role name)."
  type = map(object({
    comment       = optional(string)
    parent_roles  = optional(list(string))
    granted_roles = optional(list(string), [])
  }))
  default = {}
}

variable "role_name" {
  type    = string
  default = null
}

variable "role_comment" {
  type    = string
  default = null
}

variable "role_parent_roles" {
  type    = list(string)
  default = []
}
