variable "location" {
  description = "Azure region where the Terraform state resources will be created."
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Resource group used exclusively for Terraform state."
  type        = string
  default     = "rg-tfstate-ruoxi"
}

variable "storage_account_name" {
  description = "Globally unique Azure Storage Account name. Only lowercase letters and numbers."
  type        = string
  default     = "tfstateruoxi2026"
}

variable "container_name" {
  description = "Blob container used to store Terraform state."
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags applied to Terraform state resources."
  type        = map(string)

  default = {
    purpose     = "terraform-state"
    environment = "bootstrap"
    managed_by  = "terraform"
  }
}

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  sensitive   = true
}