terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.70.1"
    }
  }
}

provider "proxmox" {

  endpoint = var.proxmox_endpoint
  password = var.proxmox_user_password
  username = var.proxmox_user_name
  insecure = true

}