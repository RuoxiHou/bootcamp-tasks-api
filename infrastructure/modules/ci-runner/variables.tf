variable "name" {
  description = "Name of the CI runner VM."
  type        = string
}

variable "location" {
  description = "Azure region for resources."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for VM network interface."
  type        = string
}

variable "vm_size" {
  description = "VM size."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VM."
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for authentication."
  type        = string
  sensitive   = true
}

variable "admin_source_ip" {
  description = "Source IP for SSH and SonarQube access (CIDR)."
  type        = string

  validation {
    condition = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$", var.admin_source_ip))
    error_message = "admin_source_ip must be an IPv4 address or IPv4 CIDR, for example 203.0.113.10 or 203.0.113.10/32."
  }
}

variable "acr_id" {
  description = "Azure Container Registry ID."
  type        = string
}

variable "aks_id" {
  description = "Azure Kubernetes Service cluster ID."
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

variable "key_vault_id" {
  description = "Azure Key Vault resource ID."
  type        = string
}

variable "key_vault_name" {
  description = "Azure Key Vault name used by the runner for secret retrieval."
  type        = string
}

variable "github_runner_pat_secret_name" {
  description = "Key Vault secret name containing a GitHub token that can mint runner registration tokens."
  type        = string
  default     = "github-runner-pat"
}

variable "sonarqube_db_password_secret_name" {
  description = "Key Vault secret name for SonarQube DB password."
  type        = string
  default     = "sonarqube-db-password"
}

variable "tags" {
  description = "Azure resource tags."
  type        = map(string)
  default     = {}
}
