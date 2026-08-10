output "id" {
  value = azurerm_kubernetes_cluster.project3.id
}

output "name" {
  value = azurerm_kubernetes_cluster.project3.name
}

output "fqdn" {
  value = azurerm_kubernetes_cluster.project3.fqdn
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.project3.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  value = azurerm_kubernetes_cluster.project3.kubelet_identity[0].object_id
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.project3.node_resource_group
}

output "workload_identity_client_id" {
  description = "Client ID of the AKS workload identity"
  value       = azurerm_user_assigned_identity.workload.client_id
}

output "workload_identity_principal_id" {
  description = "Principal ID of the AKS workload identity"
  value       = azurerm_user_assigned_identity.workload.principal_id
}