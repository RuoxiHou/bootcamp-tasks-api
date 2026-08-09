variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "mysql_version" {
  type    = string
  default = "8.0.21"
}

variable "administrator_login" {
  type = string
}

variable "administrator_password" {
  type      = string
  sensitive = true
}

variable "database_name" {
  type = string
}

#variable "delegated_subnet_id" {
#  type = string
#}

#variable "private_dns_zone_id" {
#  type = string
#}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "mysql_sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "mysql_storage_gb" {
  type    = number
  default = 20
}

variable "mysql_backup_retention_days" {
  type    = number
  default = 7
}

variable "mysql_zone" {
  type     = string
  default  = null
  nullable = true
}

variable "mysql_ha_mode" {
  type    = string
  default = "Disabled"
}

variable "mysql_standby_zone" {
  type     = string
  default  = null
  nullable = true
}

# Remove this in production, only for testing purposes
variable "allowed_ip" {
  description = "Public IPv4 address allowed to connect to MySQL"
  type        = string
}