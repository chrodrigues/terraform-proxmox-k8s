output "dns_server_ip" {
  description = "BIND9 DNS server IP"
  value       = var.dns_server_ip
}

output "control_plane_nodes" {
  description = "Control plane nodes and their IPs"
  value       = local.control_plane_nodes
}

output "worker_nodes" {
  description = "Worker nodes and their IPs"
  value       = local.worker_nodes
}

output "next_step" {
  description = "How to bootstrap Kubernetes after the VMs are up"
  value       = "Run: cd ansible && ansible-playbook site.yml"
}
