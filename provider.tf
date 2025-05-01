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

#provider "helm" {
#  kubernetes {
#    host                   = module.eks.eks_cluster_joplium_endpoint
#    cluster_ca_certificate = base64decode(module.eks.eks_cluster_joplium_certificate_authority)
#    exec {
#      api_version = "client.authentication.k8s.io/v1beta1"
#      args        = ["eks", "get-token", "--cluster-name", module.eks.eks_cluster_name_joplium]
#      command     = "aws"
#    }
#  }
#}