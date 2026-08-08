output "profile_id" {
  value = azurerm_cdn_frontdoor_profile.project3.id
}

output "endpoint_id" {
  value = azurerm_cdn_frontdoor_endpoint.project3.id
}

output "endpoint_hostname" {
  value = azurerm_cdn_frontdoor_endpoint.project3.host_name
}