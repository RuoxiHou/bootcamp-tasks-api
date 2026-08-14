variable "domain_name" {
  description = "Public DNS domain managed by Azure DNS"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "tags" {
  type = map(string)
}