output "vm_id" {
  value       = azurerm_linux_virtual_machine.ci_runner.id
  description = "The ID of the CI runner VM."
}

output "private_ip_address" {
  value       = azurerm_network_interface.ci_runner.private_ip_address
  description = "Private IP address of the CI runner VM."
}

output "public_ip_address" {
  value       = azurerm_public_ip.ci_runner.ip_address
  description = "Public IP address of the CI runner VM."
}

output "principal_id" {
  value       = azurerm_linux_virtual_machine.ci_runner.identity[0].principal_id
  description = "Principal ID of the CI runner VM managed identity."
}

output "sonarqube_url" {
  value       = "http://${azurerm_public_ip.ci_runner.ip_address}:9000"
  description = "Public URL to access SonarQube."
}
