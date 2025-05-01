variable "proxmox_endpoint" {
  description = "Proxmox server address"
  type = string
}

variable "proxmox_user_name" {
  description = "Proxmox api token id"
  type = string
}

variable "proxmox_user_password" {
  description = "Proxmox api token secret"
  type = string
  sensitive = true
}

variable "proxmox_vm_user" {
  description = "Linux username"
  type = string
}

variable "proxmox_vm_password" {
  description = "Linux user password"
  type = string
  sensitive = true
}

variable "proxmox_node_name" {
  description = "Proxmox server name"
  type = string
}

variable "proxmox_vm_name_k8s_worker_node" {
  description = "k8s worker node name"
  type = string
  default = "k8s-worker-"
}

variable "proxmox_vm_name_k8s_control_plane" {
  description = "k8s control plane name"
  type = string
  default = "k8s-control-plane-"
}

variable "proxmox_number_of_vm_k8s_worker_node" {
  description = "Number of k8s worker nodes"
  type = string
}

variable "proxmox_number_of_vm_k8s_control_plane" {
  description = "Number of k8s control plane nodes"
  type = string
}

variable "k8s_control_plane_ip_start" {
  description = "First IP of the k8s control plane address range"
  type = string
}

variable "k8s_worker_ip_start" {
  description = "First IP of the k8s worker nodes address range"
  type = string
}

variable "proxmox_datastore_name" {
  description = "Promox datastore"
  type = string
  default = "local"
}