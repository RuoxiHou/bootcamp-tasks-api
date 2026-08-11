resource "azurerm_user_assigned_identity" "externaldns" {
  name                = "${var.project_name}-externaldns-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_federated_identity_credential" "externaldns" {
  name                = "${var.project_name}-externaldns-federated"
  resource_group_name = var.resource_group_name

  parent_id = azurerm_user_assigned_identity.externaldns.id

  audience = [
    "api://AzureADTokenExchange"
  ]

  issuer = azurerm_kubernetes_cluster.project3.oidc_issuer_url

  subject = "system:serviceaccount:default:external-dns"
}

resource "azurerm_role_assignment" "externaldns_dns" {
  scope                = var.dns_zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.externaldns.principal_id
}