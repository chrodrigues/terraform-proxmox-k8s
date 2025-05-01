module "bind9_server" {
  source = "./modules/bind9_dnsserver"
  proxmox_endpoint                       = var.proxmox_endpoint
  proxmox_user_name                      = var.proxmox_user_name
  proxmox_user_password                  = var.proxmox_user_password
  proxmox_vm_user                        = var.proxmox_vm_user
  proxmox_node_name                      = var.proxmox_node_name
  proxmox_datastore_name                 = var.proxmox_datastore_name
  vm_image_id = module.proxmox.vm_image_id
}

module "proxmox" {
  source                                 = "./modules/proxmox"
  proxmox_endpoint                       = var.proxmox_endpoint
  proxmox_vm_password                    = var.proxmox_vm_password
  proxmox_user_name                      = var.proxmox_user_name
  proxmox_user_password                  = var.proxmox_user_password
  proxmox_vm_user                        = var.proxmox_vm_user
  k8s_control_plane_ip_start             = var.k8s_control_plane_ip_start
  k8s_worker_ip_start                    = var.k8s_worker_ip_start
  proxmox_number_of_vm_k8s_control_plane = var.proxmox_number_of_vm_k8s_control_plane
  proxmox_number_of_vm_k8s_worker_node   = var.proxmox_number_of_vm_k8s_worker_node
  proxmox_node_name                      = var.proxmox_node_name

}

#TODO: install using helm on cluster bootstrap

#module "helm" {
#
#  source                             = "../../modules/helm"
#  grafana_password_admin                    = "biruleibe"
#  grafana_disk_size                         = "20Gi"
#  grafana_storageclass_name                 = "openebs"
#  prometheus_metrics_server_replicas        = "1"
#  prometheus_storageclass_name              = "openebs"
#  prometheus_disk_size                      = "20Gi"
#  prometheus_retention                      = "15d"
#
#  depends_on = [module.proxmox]
#}