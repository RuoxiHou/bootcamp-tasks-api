resource "azurerm_mysql_flexible_server" "project3" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  version = var.mysql_version

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  sku_name = var.mysql_sku_name

  zone = var.mysql_zone

  dynamic "high_availability" {
    for_each = var.mysql_ha_mode == "Disabled" ? [] : [1]
    content {
      mode                      = var.mysql_ha_mode
      standby_availability_zone = var.mysql_standby_zone
    }
  }

  storage {
    size_gb           = var.mysql_storage_gb
    auto_grow_enabled = true
  }

  backup_retention_days = var.mysql_backup_retention_days

  tags = var.tags
}

resource "azurerm_mysql_flexible_database" "project3" {
  name      = var.database_name
  server_name         = azurerm_mysql_flexible_server.project3.name
  resource_group_name = var.resource_group_name

  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"

  lifecycle {
    prevent_destroy = true
  }
}