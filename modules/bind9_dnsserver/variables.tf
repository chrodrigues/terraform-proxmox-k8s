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

variable "proxmox_node_name" {
  description = "Proxmox server name"
  type = string
}

variable "proxmox_datastore_name" {
  description = "Virtual machines datastore"
  type = string
}

variable "vm_image_id" {
  description = "Ubuntu image id"
  type = string
}