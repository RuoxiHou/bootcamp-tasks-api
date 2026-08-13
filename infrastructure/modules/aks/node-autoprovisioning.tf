resource "azurerm_role_assignment" "nap_subnet_network_contributor" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.project3.identity[0].principal_id
}

resource "azapi_update_resource" "node_autoprovisioning" {
  type        = "Microsoft.ContainerService/managedClusters@2026-04-01"
  resource_id = azurerm_kubernetes_cluster.project3.id

  body = {
    properties = {
      nodeProvisioningProfile = {
        mode = "Auto"
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.project3,
    azurerm_role_assignment.nap_subnet_network_contributor,
    azapi_update_resource.gateway_api,
  ]
}