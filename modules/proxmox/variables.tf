variable "proxmox_node_name" {
  description = "Proxmox server name"
  type        = string
}

variable "proxmox_vm_datastore_name" {
  description = "Proxmox datastore for VM disks"
  type        = string
}

variable "proxmox_datastore_name" {
  description = "Proxmox datastore"
  type        = string
  default     = "local"
}

variable "proxmox_vm_user" {
  description = "Linux username"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key content injected into the VMs"
  type        = string
}

variable "control_plane_nodes" {
  description = "Map of control plane VM names to their IPs"
  type        = map(string)
}

variable "worker_nodes" {
  description = "Map of worker VM names to their IPs"
  type        = map(string)
}

variable "network_gateway" {
  description = "Default gateway for the VMs"
  type        = string
}

variable "control_plane_cores" {
  description = "CPU cores per control plane VM"
  type        = number
  default     = 2
}

variable "control_plane_memory" {
  description = "Memory (MB) per control plane VM"
  type        = number
  default     = 4096
}

variable "control_plane_disk_size" {
  description = "OS disk size (GB) per control plane VM"
  type        = number
  default     = 40
}

variable "worker_cores" {
  description = "CPU cores per worker VM"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "Memory (MB) per worker VM"
  type        = number
  default     = 6144
}

variable "worker_disk_size" {
  description = "OS disk size (GB) per worker VM"
  type        = number
  default     = 30
}

variable "worker_data_disk_size" {
  description = "OpenEBS data disk size (GB) per worker VM"
  type        = number
  default     = 100
}
