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

variable "mysql_fqdn" {
  description = "MySQL server FQDN."
  type        = string
}

variable "mysql_database_name" {
  description = "MySQL database name."
  type        = string
}

variable "mysql_admin_username" {
  description = "MySQL admin username."
  type        = string
}

variable "redis_hostname" {
  description = "Redis hostname."
  type        = string
}

variable "redis_port" {
  description = "Redis port as string."
  type        = string
  default     = "10000"
}

variable "redis_primary_access_key" {
  description = "Redis primary access key."
  type        = string
  sensitive   = true
}

variable "github_runner_pat" {
  description = "GitHub PAT to store in Key Vault for CI runner bootstrap."
  type        = string
  sensitive   = true
}

variable "github_runner_pat_secret_name" {
  description = "Key Vault secret name for the GitHub runner PAT."
  type        = string
  default     = "github-runner-pat"
}

variable "sonarqube_db_password" {
  description = "SonarQube database password to store in Key Vault."
  type        = string
  sensitive   = true
}

variable "sonarqube_db_password_secret_name" {
  description = "Key Vault secret name for the SonarQube DB password."
  type        = string
  default     = "sonarqube-db-password"
}