resource "azurerm_cdn_frontdoor_profile" "project3" {
  name                = var.name
  resource_group_name = var.resource_group_name

  sku_name = "Standard_AzureFrontDoor"

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "project3" {
  name                     = "${var.name}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.project3.id

  enabled = true

  tags = var.tags
}