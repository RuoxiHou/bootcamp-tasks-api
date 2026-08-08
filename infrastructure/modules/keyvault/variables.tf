variable "name" {
  description = "Key Vault name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the Key Vault."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "Key Vault SKU."
  type        = string
  default     = "standard"
}

variable "vnet_id" {
  description = "VNet ID for private DNS linking."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID where the Key Vault private endpoint will be created."
  type        = string
}

variable "terraform_principal_id" {
  description = "Object ID of the identity running Terraform."
  type        = string
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}

variable "mysql_admin_password" {
  description = "MySQL administrator password."
  type        = string
  sensitive   = true
}