# Minimal cloud-init: user, SSH key, qemu-guest-agent and the OpenEBS data
# disk (workers only - the mount is "nofail" so control planes ignore it).
# Everything else (DNS, containerd, Kubernetes) is done by Ansible.
resource "proxmox_virtual_environment_file" "k8s_cloud_config" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_name
  node_name    = var.proxmox_node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    disk_setup:
      /dev/vdb:
        table_type: mbr
        layout: true
        overwrite: false
    fs_setup:
      - label: openebs
        filesystem: ext4
        device: /dev/vdb1
    mounts:
      - [ vdb1, /var/openebs/local, ext4, "defaults,nofail", 0, 0 ]
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

    file_name = "k8s-cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "k8s-control-plane" {
  for_each        = var.control_plane_nodes
  name            = each.key
  node_name       = var.proxmox_node_name
  stop_on_destroy = true

  agent {
    enabled = true
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.k8s_cloud_config.id

    ip_config {
      ipv4 {
        address = "${each.value}/24"
        gateway = var.network_gateway
      }
    }
  }

  disk {
    datastore_id = var.proxmox_vm_datastore_name
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    file_format  = "raw" # lvm-thin does not support qcow2
    iothread     = true
    discard      = "on"
    size         = var.control_plane_disk_size
  }

  cpu {
    architecture = "x86_64"
    cores        = var.control_plane_cores
    type         = "host"
  }

  memory {
    dedicated = var.control_plane_memory
  }

  network_device {
    bridge = "vmbr0"
  }
}

resource "proxmox_virtual_environment_vm" "k8s-worker-node" {
  for_each        = var.worker_nodes
  name            = each.key
  node_name       = var.proxmox_node_name
  stop_on_destroy = true

  agent {
    enabled = true
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.k8s_cloud_config.id

    ip_config {
      ipv4 {
        address = "${each.value}/24"
        gateway = var.network_gateway
      }
    }
  }

  disk {
    datastore_id = var.proxmox_vm_datastore_name
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    file_format  = "raw" # lvm-thin does not support qcow2
    iothread     = true
    discard      = "on"
    size         = var.worker_disk_size
  }

  # Extra disk used by OpenEBS local storage
  disk {
    datastore_id = var.proxmox_vm_datastore_name
    interface    = "virtio1"
    file_format  = "raw"
    iothread     = true
    discard      = "on"
    size         = var.worker_data_disk_size
  }

  cpu {
    architecture = "x86_64"
    cores        = var.worker_cores
    type         = "host"
  }

  memory {
    dedicated = var.worker_memory
  }

  network_device {
    bridge = "vmbr0"
  }
}

# Ubuntu Cloud Image
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type   = "iso"
  datastore_id   = var.proxmox_datastore_name
  node_name      = var.proxmox_node_name
  upload_timeout = 2500

  url = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
}
