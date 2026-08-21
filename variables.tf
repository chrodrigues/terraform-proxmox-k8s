variable "proxmox_endpoint" {
  description = "Proxmox server address"
  type        = string
}

variable "proxmox_user_name" {
  description = "Proxmox username (e.g. root@pam)"
  type        = string
}

variable "proxmox_user_password" {
  description = "Proxmox user password"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for the Proxmox API (self-signed certs)"
  type        = bool
  default     = true
}

variable "proxmox_vm_user" {
  description = "Linux username created on every VM (also used by Ansible over SSH)"
  type        = string
}

variable "proxmox_node_name" {
  description = "Proxmox server name"
  type        = string
  default     = "proxmox"
}

variable "proxmox_datastore_name" {
  description = "Proxmox datastore for snippets and the cloud image (must support 'snippets' and 'iso' content)"
  type        = string
  default     = "local"
}

variable "proxmox_vm_datastore_name" {
  description = "Proxmox datastore for the VM disks (must support 'images' content)"
  type        = string
  default     = "local-lvm"
}

variable "ssh_public_key_file" {
  description = "Path to the SSH public key injected into the VMs"
  type        = string
  default     = "./id_rsa.pub"
}

variable "ssh_private_key_file" {
  description = "Path to the matching SSH private key (used by Ansible)"
  type        = string
  default     = "./id_rsa"
}

variable "proxmox_number_of_vm_k8s_worker_node" {
  description = "Number of k8s worker nodes"
  type        = number
  default     = 3
}

variable "proxmox_number_of_vm_k8s_control_plane" {
  description = "Number of k8s control plane nodes"
  type        = number
  default     = 1
}

variable "proxmox_vm_name_k8s_control_plane" {
  description = "Name prefix for the k8s control plane VMs"
  type        = string
  default     = "k8s-control-plane-"
}

variable "proxmox_vm_name_k8s_worker_node" {
  description = "Name prefix for the k8s worker VMs"
  type        = string
  default     = "k8s-worker-"
}

variable "network_prefix" {
  description = "First three octets of the VM network (without trailing dot)"
  type        = string
  default     = "192.168.100"
}

variable "network_gateway" {
  description = "Default gateway for all VMs"
  type        = string
  default     = "192.168.100.1"
}

variable "dns_server_ip" {
  description = "IP address of the BIND9 DNS server VM"
  type        = string
  default     = "192.168.100.3"
}

variable "k8s_control_plane_ip_start" {
  description = "Last octet of the first control plane IP (e.g. 50 -> 192.168.100.50)"
  type        = number
  default     = 50
}

variable "k8s_worker_ip_start" {
  description = "Last octet of the first worker IP (e.g. 60 -> 192.168.100.60)"
  type        = number
  default     = 60
}

variable "domain" {
  description = "Local DNS domain for the cluster"
  type        = string
  default     = "homelab.local"
}

variable "timezone" {
  description = "Timezone configured on all VMs"
  type        = string
  default     = "America/Toronto"
}
