variable "namespace" {
  description = "Kubernetes namespace for the monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "tasks_api_namespace" {
  description = "Namespace where tasks-api is deployed"
  type        = string
  default     = "default"
}

variable "tasks_api_service_name" {
  description = "Kubernetes Service name for tasks-api"
  type        = string
  default     = "tasks-api"
}

variable "cluster_name" {
  description = "Cluster label attached to collected log streams"
  type        = string
}

variable "prometheus_storage_size" {
  description = "Persistent storage size for Prometheus"
  type        = string
  default     = "10Gi"
}

variable "loki_storage_size" {
  description = "Persistent storage size for Loki"
  type        = string
  default     = "20Gi"
}

variable "grafana_admin_password" {
  description = "Grafana administrator password"
  type        = string
  sensitive   = true
}