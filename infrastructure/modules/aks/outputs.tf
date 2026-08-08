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