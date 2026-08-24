terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.1"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.proxmox_user_name
  password = var.proxmox_user_password
  insecure = var.proxmox_insecure
}
