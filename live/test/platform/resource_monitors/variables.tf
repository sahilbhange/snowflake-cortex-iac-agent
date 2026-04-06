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

variable "enable_resource_monitor" {
  type    = bool
  default = true
}

variable "resource_monitors" {
  description = "Map of resource monitors to manage (key = monitor name)."
  type = map(object({
    credit_quota                 = number
    frequency                    = optional(string)
    start_timestamp              = optional(string)
    notify_triggers              = optional(list(number))
    suspend_trigger              = optional(number)
    suspend_immediately_trigger  = optional(number)
    notify_users                 = optional(list(string))
  }))
  default = {}
}

variable "rm_name" {
  type    = string
  default = null
}

variable "rm_credit_quota" {
  type    = number
  default = null
}

variable "rm_frequency" {
  type    = string
  default = "MONTHLY"
}

variable "rm_start_timestamp" {
  type    = string
  default = null
}
