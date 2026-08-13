resource "azurerm_key_vault" "project3" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  tenant_id = var.tenant_id
  sku_name  = var.sku_name

  rbac_authorization_enabled = true

  public_network_access_enabled = true

  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  tags = var.tags
}

resource "azurerm_key_vault_secret" "mysql_password" {
  name         = "mysql-admin-password"
  value        = var.mysql_admin_password
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_key_vault_secret" "mysql_fqdn" {
  name         = "mysql-fqdn"
  value        = var.mysql_fqdn
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_key_vault_secret" "mysql_database_name" {
  name         = "mysql-database-name"
  value        = var.mysql_database_name
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_key_vault_secret" "mysql_admin_username" {
  name         = "mysql-admin-username"
  value        = var.mysql_admin_username
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_key_vault_secret" "redis_hostname" {
  name         = "redis-hostname"
  value        = var.redis_hostname
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_key_vault_secret" "redis_port" {
  name         = "redis-port"
  value        = var.redis_port
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_key_vault_secret" "redis_password" {
  name         = "redis-password"
  value        = var.redis_primary_access_key
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_key_vault_secret" "github_runner_pat" {
  name         = var.github_runner_pat_secret_name
  value        = var.github_runner_pat
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_key_vault_secret" "sonarqube_db_password" {
  name         = var.sonarqube_db_password_secret_name
  value        = var.sonarqube_db_password
  key_vault_id = azurerm_key_vault.project3.id
  depends_on   = [azurerm_role_assignment.terraform_admin]
}

resource "azurerm_private_dns_zone" "project3" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}


resource "azurerm_private_dns_zone_virtual_network_link" "project3" {
  name                  = "${var.name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.project3.name

  virtual_network_id = var.vnet_id

  registration_enabled = false

  tags = var.tags
}


resource "azurerm_private_endpoint" "project3" {
  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  subnet_id = var.private_endpoint_subnet_id

  private_service_connection {
    name = "${var.name}-private-connection"

    private_connection_resource_id = azurerm_key_vault.project3.id

    is_manual_connection = false

    subresource_names = [
      "vault"
    ]
  }

  private_dns_zone_group {
    name = "${var.name}-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.project3.id
    ]
  }

  tags = var.tags
}


resource "azurerm_role_assignment" "terraform_admin" {
  scope                = azurerm_key_vault.project3.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.terraform_principal_id
}