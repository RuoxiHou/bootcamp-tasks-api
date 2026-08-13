resource "azurerm_user_assigned_identity" "workload" {
  name                = "${var.project_name}-workload-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_federated_identity_credential" "tasks_api" {
  name = "${var.project_name}-tasks-api-federated"

  user_assigned_identity_id = azurerm_user_assigned_identity.workload.id

  audience = [
    "api://AzureADTokenExchange"
  ]

  issuer = azurerm_kubernetes_cluster.project3.oidc_issuer_url

  subject = "system:serviceaccount:default:tasks-api"
}

resource "azurerm_role_assignment" "workload_keyvault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}