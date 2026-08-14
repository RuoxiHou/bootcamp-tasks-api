output "vnet_id" {
  value = azurerm_virtual_network.project3.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "mysql_subnet_id" {
  value = azurerm_subnet.mysql.id
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "ci_subnet_id" {
  value = azurerm_subnet.ci.id
}

output "mysql_private_dns_zone_id" {
  value = azurerm_private_dns_zone.mysql.id
}

output "redis_private_dns_zone_id" {
  value = azurerm_private_dns_zone.redis.id
}