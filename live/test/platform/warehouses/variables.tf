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

variable "enable_warehouse" {
  type    = bool
  default = true
}

variable "warehouses" {
  description = "Map of warehouses to manage (key = warehouse name)."
  type = map(object({
    size               = optional(string)
    auto_suspend       = optional(number)
    auto_resume        = optional(bool)
    min_cluster_count  = optional(number)
    max_cluster_count  = optional(number)
    comment            = optional(string)
  }))
  default = {}
}

variable "warehouse_name" {
  type    = string
  default = null
}

variable "warehouse_size" {
  type    = string
  default = "XSMALL"
}

variable "warehouse_auto_suspend" {
  type    = number
  default = 300
}

variable "warehouse_auto_resume" {
  type    = bool
  default = true
}

variable "warehouse_min_cluster_count" {
  type    = number
  default = 1
}

variable "warehouse_max_cluster_count" {
  type    = number
  default = 1
}

variable "warehouse_comment" {
  type    = string
  default = null
}
