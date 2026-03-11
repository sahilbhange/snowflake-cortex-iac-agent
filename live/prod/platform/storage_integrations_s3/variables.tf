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

variable "enable_storage_integration_s3" {
  type    = bool
  default = true
}

variable "storage_integrations" {
  description = "Map of storage integrations to manage (key = integration name)."
  type = map(object({
    allowed_locations = list(string)
    blocked_locations = optional(list(string))
    aws_role_arn      = optional(string)
    enabled           = optional(bool)
    comment           = optional(string)
  }))
  default = {}
}

variable "si_name" {
  type    = string
  default = null
}

variable "si_allowed_locations" {
  type    = list(string)
  default = []
}

variable "si_blocked_locations" {
  type    = list(string)
  default = []
}

variable "si_aws_role_arn" {
  type    = string
  default = null
}

variable "si_enabled" {
  type    = bool
  default = null
}

variable "si_comment" {
  type    = string
  default = null
}
variable "aws_role_arn" {
  type    = string
  default = null
}
