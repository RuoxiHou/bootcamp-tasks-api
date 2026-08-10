variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku_name" {
  type    = string
  default = "Balanced_B3"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID used for the Redis private endpoint"
  type        = string
}

variable "redis_private_dns_zone_id" {
  description = "Private DNS zone ID for Azure Managed Redis"
  type        = string
}