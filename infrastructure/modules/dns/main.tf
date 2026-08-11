resource "azurerm_dns_zone" "project3" {
  name                = var.domain_name
  resource_group_name = var.resource_group_name

  tags = var.tags
}