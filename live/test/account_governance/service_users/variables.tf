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

variable "enable_service_users" {
  type    = bool
  default = true
}

variable "service_users" {
  description = "Map of service users to create (key = user name). TYPE=SERVICE — key-pair auth only."
  type = map(object({
    login_name        = optional(string)
    display_name      = optional(string)
    disabled          = optional(bool, false)
    default_role      = optional(string)
    default_warehouse = optional(string)
    rsa_public_key    = optional(string)
    rsa_public_key_2  = optional(string)
    comment           = optional(string)
    roles             = optional(list(string), [])
  }))
  default = {}
}
