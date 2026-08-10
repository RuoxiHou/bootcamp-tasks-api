resource "azapi_update_resource" "gateway_api" {
  type        = "Microsoft.ContainerService/managedClusters@2026-04-01"
  resource_id = azurerm_kubernetes_cluster.project3.id

  body = {
    properties = {
      ingressProfile = {
        gatewayAPI = {
          installation = "Standard"
        }

        webAppRouting = {
          gatewayAPIImplementations = {
            appRoutingIstio = {
              mode = "Enabled"
            }
          }
        }
      }
    }
  }

  depends_on = [
    azurerm_kubernetes_cluster.project3
  ]
}