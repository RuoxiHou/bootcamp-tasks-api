terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-ruoxi"
    storage_account_name = "tfstateruoxi2026"
    container_name       = "tfstate"
    key                  = "infrastructure/terraform.tfstate"
  }
}

