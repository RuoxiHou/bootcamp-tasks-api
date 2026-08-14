variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "aks_subnet_prefix" {
  type = list(string)
}

variable "mysql_subnet_prefix" {
  type = list(string)
}

variable "private_endpoint_subnet_prefix" {
  type = list(string)
}

variable "ci_subnet_prefix" {
  type = list(string)
}

variable "project_name" {
  type    = string
  default = "project3"
}

variable "tags" {
  type    = map(string)
  default = {}
}