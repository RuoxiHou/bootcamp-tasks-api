data "azurerm_kubernetes_cluster" "project3" {
  name                = "${var.project_name}-aks"
  resource_group_name = var.resource_group_name
}