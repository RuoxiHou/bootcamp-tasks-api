variable "namespace" {
  description = "Namespace where KEDA is installed."
  type        = string
  default     = "keda"
}

variable "chart_version" {
  description = "Pinned KEDA Helm chart version."
  type        = string
  default     = "2.20.2"
}

variable "operator_replica_count" {
  description = "Number of KEDA operator replicas for failover resilience."
  type        = number
  default     = 2
}