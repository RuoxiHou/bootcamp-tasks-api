variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  sensitive   = true
}

variable "student_name" {
  description = "Student name used for resource naming."
  type        = string
  default     = "ruoxi"
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "East US"
}


variable "resource_group_name" {
  description = "Main project resource group."
  type        = string
  default     = "rg-project3-ruoxi"
}

variable "project_name" {
  description = "Short project name used in resource naming."
  type        = string
  default     = "project3"
}


variable "vnet_address_space" {
  description = "Virtual network address space."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "AKS subnet."
  type        = list(string)
  default     = ["10.10.1.0/23"]
}

variable "mysql_subnet_prefix" {
  description = "MySQL delegated subnet."
  type        = list(string)
  default     = ["10.10.2.0/24"]
}

variable "private_endpoint_subnet_prefix" {
  description = "Subnet for private endpoints."
  type        = list(string)
  default     = ["10.10.3.0/24"]
}

variable "ci_subnet_prefix" {
  description = "CI/CD runner subnet."
  type        = list(string)
  default     = ["10.10.4.0/24"]
}

variable "aks_node_count" {
  description = "Number of AKS system nodes."
  type        = number
  default     = 2
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes."
  type        = string
  default     = "Standard_D4als_v7"
}

variable "aks_zones" {
  description = "Availability zones for AKS node pool. Leave empty for regions/SKUs without zone support."
  type        = list(string)
  default     = ["1", "2"]
}

variable "mysql_admin_username" {
  description = "MySQL administrator username."
  type        = string
  default     = "mysqladmin"
}

variable "mysql_admin_password" {
  description = "MySQL administrator password."
  type        = string
  sensitive   = true
}

variable "mysql_database_name" {
  description = "Application database name."
  type        = string
  default     = "tasksdb"
}

variable "mysql_version" {
  description = "MySQL server version."
  type        = string
  default     = "8.0.21"
}

variable "mysql_sku_name" {
  description = "MySQL Flexible Server SKU. Use Burstable for lowest cost."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "mysql_storage_gb" {
  description = "MySQL storage size in GB. Keep low to control cost."
  type        = number
  default     = 20
}

variable "mysql_backup_retention_days" {
  description = "MySQL backup retention in days."
  type        = number
  default     = 7
}

variable "mysql_zone" {
  description = "Primary availability zone for MySQL. Set null to let Azure choose."
  type        = string
  default     = null
  nullable    = true
}

variable "mysql_ha_mode" {
  description = "MySQL high availability mode: Disabled, SameZone, or ZoneRedundant."
  type        = string
  default     = "Disabled"
}

variable "mysql_standby_zone" {
  description = "Standby zone when HA is enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "redis_sku" {
  description = "Azure Managed Redis SKU."
  type        = string
  default     = "Balanced_B1"
}

variable "tags" {
  description = "Common Azure resource tags."
  type        = map(string)

  default = {
    project    = "project3"
    managed_by = "terraform"
  }
}

variable "key_vault_name" {
  description = "Globally unique Key Vault name."
  type        = string
}

variable "key_vault_sku" {
  description = "Key Vault SKU."
  type        = string
  default     = "standard"
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
  sensitive   = true
}

variable "terraform_principal_id" {
  description = "Object ID of the identity running Terraform."
  type        = string
}


variable "domain_name" {
  description = "Public domain name managed by Azure DNS"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for CI runner VM authentication."
  type        = string
  sensitive   = true
}

variable "admin_source_ip" {
  description = "Admin source IP for SSH and SonarQube access (CIDR)."
  type        = string
}

variable "github_org" {
  description = "GitHub organization/owner name."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_runner_pat_secret_name" {
  description = "Key Vault secret name containing a GitHub token for runner registration."
  type        = string
  default     = "github-runner-pat"
}

variable "github_runner_pat" {
  description = "GitHub PAT value that Terraform stores in Key Vault for runner bootstrap."
  type        = string
  sensitive   = true
}

variable "sonarqube_db_password" {
  description = "Stable SonarQube database password stored in Key Vault and consumed by the CI runner bootstrap."
  type        = string
  sensitive   = true
}

variable "sonarqube_db_password_secret_name" {
  description = "Key Vault secret name for SonarQube database password."
  type        = string
  default     = "sonarqube-db-password"
}

variable "ci_runner_vm_size" {
  description = "VM size for the self-hosted CI runner. Defaults to a burstable SKU to avoid DSv5 quota requirements."
  type        = string
  default     = "Standard_B2s"
}

variable "grafana_admin_password" {
  description = "Grafana administrator password"
  type        = string
  sensitive   = true
}