module "resource_group" {
  source = "./modules/resource-group"

  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "keyvault" {
  source = "./modules/keyvault"

  name                = var.key_vault_name
  resource_group_name = module.resource_group.name
  location            = var.location

  tenant_id = var.tenant_id

  sku_name = var.key_vault_sku

  vnet_id                    = module.network.vnet_id
  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id

  terraform_principal_id = var.terraform_principal_id

  mysql_admin_password = var.mysql_admin_password

  mysql_fqdn           = module.mysql.fqdn
  mysql_database_name  = module.mysql.database_name
  mysql_admin_username = var.mysql_admin_username

  redis_hostname           = module.redis.hostname
  redis_port               = tostring(coalesce(module.redis.port, 10000))
  redis_primary_access_key = module.redis.primary_access_key

  tags = var.tags

  depends_on = [module.network, module.mysql, module.redis]
}

module "network" {
  source = "./modules/network"

  resource_group_name = module.resource_group.name
  location            = var.location
  project_name        = var.project_name

  vnet_address_space             = var.vnet_address_space
  aks_subnet_prefix              = var.aks_subnet_prefix
  mysql_subnet_prefix            = var.mysql_subnet_prefix
  private_endpoint_subnet_prefix = var.private_endpoint_subnet_prefix

  tags = var.tags
}

module "aks" {
  source              = "./modules/aks"
  project_name        = var.project_name
  name                = "${var.project_name}-aks"
  resource_group_name = module.resource_group.name
  location            = var.location

  key_vault_id = module.keyvault.id

  dns_zone_id = module.dns.id

  kubernetes_version = null

  node_count = var.aks_node_count
  vm_size    = var.aks_vm_size

  subnet_id = module.network.aks_subnet_id

  zones = var.aks_zones

  tags = var.tags

  depends_on = [module.network, module.keyvault, module.dns]
}

module "mysql" {
  source = "./modules/mysql"

  name                = "${var.project_name}-mysql"
  resource_group_name = module.resource_group.name
  location            = var.location

  mysql_version               = var.mysql_version
  administrator_login         = var.mysql_admin_username
  administrator_password      = var.mysql_admin_password
  database_name               = var.mysql_database_name
  mysql_sku_name              = var.mysql_sku_name
  mysql_storage_gb            = var.mysql_storage_gb
  mysql_backup_retention_days = var.mysql_backup_retention_days
  mysql_zone                  = var.mysql_zone
  mysql_ha_mode               = var.mysql_ha_mode
  mysql_standby_zone          = var.mysql_standby_zone

  delegated_subnet_id = module.network.mysql_subnet_id
  private_dns_zone_id = module.network.mysql_private_dns_zone_id

  tags = var.tags

  depends_on = [module.network]
}

module "redis" {
  source = "./modules/redis"

  name                = "${var.project_name}-redis"
  resource_group_name = module.resource_group.name
  location            = var.location

  sku_name = var.redis_sku

  private_endpoint_subnet_id = module.network.private_endpoint_subnet_id
  redis_private_dns_zone_id  = module.network.redis_private_dns_zone_id

  tags = var.tags
}

module "frontdoor" {
  source = "./modules/frontdoor"

  name                = "${var.project_name}-fd"
  resource_group_name = module.resource_group.name

  tags = var.tags
}

module "acr" {
  source = "./modules/acr"

  name                = "${var.project_name}${var.student_name}acr"
  resource_group_name = module.resource_group.name
  location            = var.location

  sku = "Basic"

  tags = var.tags
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity_object_id
}

module "dns" {
  source = "./modules/dns"

  domain_name         = var.domain_name
  resource_group_name = module.resource_group.name

  tags = var.tags

  depends_on = [
    module.resource_group
  ]
}

