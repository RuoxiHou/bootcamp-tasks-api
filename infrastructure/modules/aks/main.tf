terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    azapi = {
      source = "Azure/azapi"
    }
  }
}

resource "azurerm_kubernetes_cluster" "project3" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  dns_prefix = var.name

  kubernetes_version = var.kubernetes_version

  role_based_access_control_enabled = true

  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  identity {
    type = "SystemAssigned"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  default_node_pool {
    name = "system"

    vm_size    = var.vm_size
    node_count = var.node_count

    type = "VirtualMachineScaleSets"

    zones = length(var.zones) > 0 ? var.zones : null

    vnet_subnet_id = var.subnet_id

    only_critical_addons_enabled = false

    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"

    network_policy = "azure"
  }

  tags = var.tags
}

