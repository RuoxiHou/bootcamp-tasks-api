output "id" {
  value = azurerm_managed_redis.project3.id
}

output "hostname" {
  value = azurerm_managed_redis.project3.hostname
}

output "port" {
  value = try(azurerm_managed_redis.project3.default_database[0].port, null)
}

output "primary_access_key" {
  value     = try(azurerm_managed_redis.project3.default_database[0].primary_access_key, null)
  sensitive = true
}