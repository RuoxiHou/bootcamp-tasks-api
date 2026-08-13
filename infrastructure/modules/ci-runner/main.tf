locals {
  admin_source_ip_parts = split("/", var.admin_source_ip)
  admin_source_prefix = (
    length(local.admin_source_ip_parts) == 1
    ? format("%s/32", var.admin_source_ip)
    : (
        local.admin_source_ip_parts[1] == "32" || local.admin_source_ip_parts[0] == cidrhost(var.admin_source_ip, 0)
        ? var.admin_source_ip
        : format("%s/32", local.admin_source_ip_parts[0])
      )
  )
}

resource "azurerm_network_security_group" "ci_runner" {
  name                = "${var.name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.admin_source_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "sonarqube"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = local.admin_source_prefix
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "ci_runner" {
  name                = "${var.name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "ci_runner" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ci_runner.id
  }
}

resource "azurerm_network_interface_security_group_association" "ci_runner" {
  network_interface_id      = azurerm_network_interface.ci_runner.id
  network_security_group_id = azurerm_network_security_group.ci_runner.id
}

resource "azurerm_linux_virtual_machine" "ci_runner" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.ci_runner.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init-bootstrap.sh", {
    admin_username                = var.admin_username
    github_org                    = var.github_org
    github_repo                   = var.github_repo
    key_vault_name                = var.key_vault_name
    github_runner_pat_secret_name = var.github_runner_pat_secret_name
    sonarqube_db_password_secret_name = var.sonarqube_db_password_secret_name
  }))
}

resource "azurerm_role_assignment" "acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_linux_virtual_machine.ci_runner.identity[0].principal_id
}

resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = var.aks_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_linux_virtual_machine.ci_runner.identity[0].principal_id
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.ci_runner.identity[0].principal_id
}