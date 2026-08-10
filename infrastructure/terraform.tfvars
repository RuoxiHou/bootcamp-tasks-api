subscription_id = "daf9c53c-7096-4293-9bb1-f7ad8263db1a"

location = "East US"

resource_group_name = "rg-project3-ruoxi"

project_name = "project3"

student_name = "ruoxi"

vnet_address_space = [
  "10.10.0.0/16"
]

aks_subnet_prefix = [
  "10.10.1.0/24"
]

mysql_subnet_prefix = [
  "10.10.2.0/24"
]

private_endpoint_subnet_prefix = [
  "10.10.3.0/24"
]

aks_node_count = 2
aks_vm_size    = "Standard_D4als_v7"
aks_zones      = ["1", "2"]

mysql_admin_username        = "mysqladmin"
mysql_admin_password        = "MysqlAdmin#2026"
mysql_database_name         = "tasksdb"
mysql_version               = "8.0.21"
mysql_sku_name              = "B_Standard_B1ms"
mysql_storage_gb            = 20
mysql_backup_retention_days = 7
mysql_zone                  = null
mysql_ha_mode               = "Disabled"
mysql_standby_zone          = null

redis_sku = "Balanced_B1"

key_vault_name = "kv-project3-ruoxi"

tenant_id = "84f58ce9-43c8-4932-b908-591a8a3007d3"

terraform_principal_id = "396bf63d-e075-4c64-ae02-e9bc7ab53492"
