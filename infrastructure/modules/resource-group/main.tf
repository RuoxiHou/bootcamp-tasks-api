resource "azurerm_resource_group" "project3" {
  name     = var.name
  location = var.location

  tags = var.tags
}