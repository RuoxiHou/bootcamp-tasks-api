resource "azurerm_managed_redis" "project3" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_name = var.sku_name

  high_availability_enabled = true

  public_network_access = "Disabled"

  default_database {
    access_keys_authentication_enabled = true
  }

  lifecycle {
    ignore_changes = [default_database]
  }

  tags = var.tags
}