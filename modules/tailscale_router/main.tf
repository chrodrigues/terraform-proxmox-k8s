# Minimal cloud-init: hostname, user, SSH key and qemu-guest-agent.
# Tailscale itself is installed and joined to the tailnet by Ansible (ansible/roles/tailscale).
resource "proxmox_virtual_environment_file" "tailscale_cloud_config" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_name
  node_name    = var.proxmox_node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: tailscale-router
    users:
      - default
      - name: ${var.proxmox_vm_user}
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.ssh_public_key}
        sudo: ALL=(ALL) NOPASSWD:ALL
    package_update: true
    packages:
      - qemu-guest-agent
    runcmd:
      - systemctl enable --now qemu-guest-agent
    EOF

    file_name = "tailscale-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "tailscale-router" {
  name            = "tailscale-router"
  node_name       = var.proxmox_node_name
  stop_on_destroy = true

  agent {
    enabled = true
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.tailscale_cloud_config.id

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/24"
        gateway = var.network_gateway
      }
    }
  }

  disk {
    datastore_id = var.proxmox_vm_datastore_name
    file_id      = var.vm_image_id
    interface    = "virtio0"
    file_format  = "raw" # lvm-thin does not support qcow2
    iothread     = true
    discard      = "on"
    size         = 10
  }

  cpu {
    architecture = "x86_64"
    cores        = 1
    type         = "host"
  }

  memory {
    dedicated = 1024
  }

  network_device {
    bridge = "vmbr0"
  }
}
