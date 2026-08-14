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

resource "azurerm_private_endpoint" "redis" {
  name                = "${var.name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name}-private-connection"
    private_connection_resource_id = azurerm_managed_redis.project3.id

    is_manual_connection = false

    subresource_names = [
      "redisEnterprise"
    ]
  }

  private_dns_zone_group {
    name = "redis-dns-zone-group"

    private_dns_zone_ids = [
      var.redis_private_dns_zone_id
    ]
  }

  tags = var.tags
}