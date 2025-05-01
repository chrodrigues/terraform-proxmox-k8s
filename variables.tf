variable "proxmox_endpoint" {
  description = "Proxmox server address"
  type        = string
}

variable "proxmox_user_name" {
  description = "Proxmox api token id"
  type        = string
}

variable "proxmox_user_password" {
  description = "Proxmox api token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_vm_user" {
  description = "Linux username"
  type        = string
}

variable "proxmox_vm_password" {
  description = "Linux user password"
  type        = string
  sensitive   = true
}

variable "proxmox_number_of_vm_k8s_worker_node" {
  description = "Number of k8s worker nodes"
  type        = string
  default     = "3"
}

variable "proxmox_number_of_vm_k8s_control_plane" {
  description = "Number of k8s control plane nodes"
  type        = string
  default     = "1"
}

variable "k8s_control_plane_ip_start" {
  description = "First IP of the k8s control plane address range"
  type        = string
  default     = "50"
}

variable "k8s_worker_ip_start" {
  description = "First IP of the k8s worker address range"
  type        = string
  default     = "60"
}

variable "proxmox_node_name" {
  description = "Proxmox server name"
  type        = string
  default     = "proxmox"
}

variable "proxmox_datastore_name" {
  description = "Proxmox datastore"
  type = string
  default = "local"
}
variable "prometheus_metrics_server_replicas" {
  type        = string
  description = "Number of prometheus metrics server replicas"
  default     = 1
}

variable "prometheus_retention" {
  type        = string
  description = "Retention in days for prometheus"
  default     = "7"
}

variable "prometheus_storageclass_name" {
  type        = string
  description = "Storage class name"
  default     = "openebs"
}

variable "prometheus_disk_size" {
  type        = string
  description = "Disk size for prometheus"
  default     = 50
}


variable "grafana_password_admin" {
  type        = string
  description = "Password for admin user"
}

variable "grafana_disk_size" {
  type        = string
  description = "Disk size for grafana"
  default     = 10
}

variable "grafana_storageclass_name" {
  type        = string
  description = "Storage class name"
  default     = "openebs"
}