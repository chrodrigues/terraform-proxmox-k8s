variable "prometheus_metrics_server_replicas" {
  type        = string
  description = "Number of prometheus metrics server replicas"
}

variable "prometheus_retention" {
  type        = string
  description = "Retention in days for prometheus"
}

variable "prometheus_storageclass_name" {
  type        = string
  description = "Storage class name"
}

variable "prometheus_disk_size" {
  type        = string
  description = "Disk size for prometheus"
}


variable "grafana_password_admin" {
  type        = string
  description = "Password for admin user"
}

variable "grafana_disk_size" {
  type        = string
  description = "Disk size for grafana"
}

variable "grafana_storageclass_name" {
  type        = string
  description = "Storage class name"
}