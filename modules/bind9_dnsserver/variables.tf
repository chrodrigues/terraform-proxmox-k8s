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
}

variable "proxmox_vm_user" {
  description = "Linux username"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key content injected into the VM"
  type        = string
}

variable "dns_server_ip" {
  description = "IP address of the DNS server VM"
  type        = string
}

variable "network_gateway" {
  description = "Default gateway for the VM"
  type        = string
}

variable "vm_image_id" {
  description = "Ubuntu image id"
  type        = string
}
