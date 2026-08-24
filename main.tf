locals {
  control_plane_nodes = {
    for i in range(var.proxmox_number_of_vm_k8s_control_plane) :
    "${var.proxmox_vm_name_k8s_control_plane}${i}" => "${var.network_prefix}.${var.k8s_control_plane_ip_start + i}"
  }

  worker_nodes = {
    for i in range(var.proxmox_number_of_vm_k8s_worker_node) :
    "${var.proxmox_vm_name_k8s_worker_node}${i}" => "${var.network_prefix}.${var.k8s_worker_ip_start + i}"
  }
}

data "local_file" "ssh_public_key" {
  filename = pathexpand(var.ssh_public_key_file)
}

module "proxmox" {
  source = "./modules/proxmox"

  proxmox_node_name         = var.proxmox_node_name
  proxmox_datastore_name    = var.proxmox_datastore_name
  proxmox_vm_datastore_name = var.proxmox_vm_datastore_name
  proxmox_vm_user           = var.proxmox_vm_user
  ssh_public_key            = trimspace(data.local_file.ssh_public_key.content)

  control_plane_nodes = local.control_plane_nodes
  worker_nodes        = local.worker_nodes
  network_gateway     = var.network_gateway
}

module "bind9_server" {
  source = "./modules/bind9_dnsserver"

  proxmox_node_name         = var.proxmox_node_name
  proxmox_datastore_name    = var.proxmox_datastore_name
  proxmox_vm_datastore_name = var.proxmox_vm_datastore_name
  proxmox_vm_user           = var.proxmox_vm_user
  ssh_public_key            = trimspace(data.local_file.ssh_public_key.content)

  dns_server_ip   = var.dns_server_ip
  network_gateway = var.network_gateway
  vm_image_id     = module.proxmox.vm_image_id
}

# Ansible inventory and variables generated from the Terraform state,
# so the VM list and IPs have a single source of truth.
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/ansible/inventory/hosts.yml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    vm_user             = var.proxmox_vm_user
    ssh_private_key     = abspath(pathexpand(var.ssh_private_key_file))
    dns_ip              = var.dns_server_ip
    control_plane_nodes = local.control_plane_nodes
    worker_nodes        = local.worker_nodes
  })
}

resource "local_file" "ansible_terraform_vars" {
  filename        = "${path.module}/ansible/group_vars/all/terraform.yml"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/ansible_vars.yml.tftpl", {
    domain                 = var.domain
    dns_server_ip          = var.dns_server_ip
    network_prefix         = var.network_prefix
    control_plane_endpoint = local.control_plane_nodes["${var.proxmox_vm_name_k8s_control_plane}0"]
    timezone               = var.timezone
    vm_user                = var.proxmox_vm_user
  })
}

#TODO: helm module for Prometheus/Grafana once the cluster is up (see modules/helm)
#TODO: prepare one node to be the "IA node" (https://hub.docker.com/r/ollama/ollama)
