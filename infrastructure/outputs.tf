output "resource_group_name" {
  value = module.resource_group.name
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "aks_name" {
  value = module.aks.name
}

output "aks_fqdn" {
  value = module.aks.fqdn
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "mysql_fqdn" {
  value = module.mysql.fqdn
}

output "mysql_database_name" {
  value = module.mysql.database_name
}

output "redis_hostname" {
  value = module.redis.hostname
}

output "redis_port" {
  value = module.redis.port
}

output "redis_primary_access_key" {
  value     = module.redis.primary_access_key
  sensitive = true
}

output "frontdoor_endpoint_hostname" {
  value = module.frontdoor.endpoint_hostname
}

output "key_vault_name" {
  value = module.keyvault.name
}

output "key_vault_id" {
  value = module.keyvault.id
}

output "key_vault_uri" {
  value = module.keyvault.vault_uri
}

output "key_vault_private_endpoint_id" {
  value = module.keyvault.private_endpoint_id
}