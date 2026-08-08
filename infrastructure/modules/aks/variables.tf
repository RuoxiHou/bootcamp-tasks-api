variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "node_count" {
  type    = number
  default = 2
}

variable "vm_size" {
  type    = string
  default = "Standard_D4als_v7"
}

variable "subnet_id" {
  type = string
}

variable "zones" {
  type    = list(string)
  default = ["1", "2"]
}

variable "tags" {
  type    = map(string)
  default = {}
}