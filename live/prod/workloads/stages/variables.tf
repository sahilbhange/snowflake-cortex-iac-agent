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

variable "enable_stage" {
  type    = bool
  default = true
}

variable "stage_database" {
  type    = string
  default = null
}

variable "stages" {
  description = "Map of stages to manage (key = stage name)."
  type = map(object({
    database            = optional(string)
    schema              = optional(string)
    url                 = optional(string)
    storage_integration = optional(string)
    comment             = optional(string)
  }))
  default = {}
}

variable "stage_schema" {
  type    = string
  default = null
}

variable "stage_name" {
  type    = string
  default = null
}

variable "stage_url" {
  type    = string
  default = null
}

variable "stage_storage_integration" {
  type    = string
  default = null
}

variable "stage_comment" {
  type    = string
  default = null
}
