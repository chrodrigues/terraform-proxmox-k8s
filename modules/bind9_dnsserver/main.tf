# DNS Server Cloud-Init Configuration
resource "proxmox_virtual_environment_file" "dns_cloud_config" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_name
  node_name    = var.proxmox_node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    hostname: bind9-dns-server
    users:
      - default
      - name: ${var.proxmox_vm_user}
        groups:
          - sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ${trimspace(data.local_file.ssh_public_key.content)}
        sudo: ALL=(ALL) NOPASSWD:ALL
    write_files:
      - path: /etc/hosts
        content: |
          127.0.0.1 localhost
          192.168.100.3 bind9-dns-server bind9-dns-server.homelab.local homelab.local
        permissions: '0644'
      - path: /tmp/named.conf.options
        content: |
          options {
              directory "/var/cache/bind";
              allow-query { any; };
              recursion yes;
              forwarders { 8.8.8.8; 8.8.4.4; };
              dnssec-validation auto;
              listen-on-v6 { any; };
          };
        permissions: '0644'
      - path: /tmp/named.conf.local
        content: |
          zone "homelab.local" IN {
              type master;
              file "/etc/bind/db.homelab.local";
              allow-update { none; };
          };
          zone "100.168.192.in-addr.arpa" IN {
              type master;
              file "/etc/bind/db.192.168.100";
              allow-update { none; };
          };
        permissions: '0644'
      - path: /tmp/db.homelab.local
        content: |
          $TTL 86400
          @   IN  SOA  ns1.homelab.local. admin.homelab.local. (
                    2025042202 ; Serial
                    3600       ; Refresh
                    1800       ; Retry
                    604800     ; Expire
                    86400      ; Minimum TTL
          )
          @       IN  NS   ns1.homelab.local.
          ns1     IN  A    192.168.100.3
          dns     IN  A    192.168.100.3
          bind9-dns-server IN A 192.168.100.3
        permissions: '0644'
      - path: /tmp/db.192.168.100
        content: |
          $TTL 86400
          @   IN  SOA  ns1.homelab.local. admin.homelab.local. (
                    2025042202 ; Serial
                    3600       ; Refresh
                    1800       ; Retry
                    604800     ; Expire
                    86400      ; Minimum TTL
          )
          @       IN  NS   ns1.homelab.local.
          3       IN  PTR  ns1.homelab.local.
          3       IN  PTR  bind9-dns-server.homelab.local.
        permissions: '0644'
      - path: /etc/resolv.conf
        content: |
          nameserver 127.0.0.1
          nameserver 8.8.8.8
          search homelab.local
        permissions: '0644'
    runcmd:
      - echo "Starting DNS server setup" > /tmp/dns-config.log
      - systemctl disable systemd-resolved >> /tmp/dns-config.log 2>&1
      - systemctl stop systemd-resolved >> /tmp/dns-config.log 2>&1
      - apt update >> /tmp/dns-config.log 2>&1 || { echo "apt update failed" >> /tmp/dns-config.log; exit 1; }
      - DEBIAN_FRONTEND=noninteractive apt install -y -o Dpkg::Options::="--force-confnew" bind9 bind9utils qemu-guest-agent >> /tmp/dns-config.log 2>&1 || { echo "apt install failed" >> /tmp/dns-config.log; exit 1; }
      - mv /tmp/named.conf.options /etc/bind/named.conf.options >> /tmp/dns-config.log 2>&1
      - mv /tmp/named.conf.local /etc/bind/named.conf.local >> /tmp/dns-config.log 2>&1
      - mv /tmp/db.homelab.local /etc/bind/db.homelab.local >> /tmp/dns-config.log 2>&1
      - mv /tmp/db.192.168.100 /etc/bind/db.192.168.100 >> /tmp/dns-config.log 2>&1
      - chown bind:bind /etc/bind /etc/bind/* >> /tmp/dns-config.log 2>&1
      - named-checkconf /etc/bind/named.conf.local >> /tmp/dns-config.log 2>&1 || { echo "named.conf.local check failed" >> /tmp/dns-config.log; exit 1; }
      - named-checkzone homelab.local /etc/bind/db.homelab.local >> /tmp/dns-config.log 2>&1 || { echo "homelab.local zone check failed" >> /tmp/dns-config.log; exit 1; }
      - named-checkzone 100.168.192.in-addr.arpa /etc/bind/db.192.168.100 >> /tmp/dns-config.log 2>&1 || { echo "reverse zone check failed" >> /tmp/dns-config.log; exit 1; }
      - systemctl enable named >> /tmp/dns-config.log 2>&1
      - systemctl restart named >> /tmp/dns-config.log 2>&1 || { echo "named start failed" >> /tmp/dns-config.log; exit 1; }
      - sleep 5
      - systemctl status named >> /tmp/dns-config.log 2>&1 || { echo "named service not running" >> /tmp/dns-config.log; exit 1; }
      - systemctl enable qemu-guest-agent >> /tmp/dns-config.log 2>&1
      - systemctl start qemu-guest-agent >> /tmp/dns-config.log 2>&1
      - timedatectl set-timezone America/Toronto >> /tmp/dns-config.log 2>&1
      - nslookup ns1.homelab.local 127.0.0.1 >> /tmp/dns-config.log 2>&1 || { echo "DNS resolution failed for ns1.homelab.local" >> /tmp/dns-config.log; exit 1; }
      - nslookup dns.homelab.local 127.0.0.1 >> /tmp/dns-config.log 2>&1 || { echo "DNS resolution failed for dns.homelab.local" >> /tmp/dns-config.log; exit 1; }
      - nslookup bind9-dns-server.homelab.local 127.0.0.1 >> /tmp/dns-config.log 2>&1 || { echo "DNS resolution failed for bind9-dns-server.homelab.local" >> /tmp/dns-config.log; exit 1; }
      - echo "DNS server setup complete" > /tmp/dns-config.done
    EOF

    file_name = "dns-cloud-config.yaml"
  }
}

# DNS Server VM
resource "proxmox_virtual_environment_vm" "bind9-dns-server" {
  name        = "bind9-dns-server"
  node_name   = var.proxmox_node_name
  stop_on_destroy = true

  agent {
    enabled = true
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.dns_cloud_config.id

    ip_config {
      ipv4 {
        address = "192.168.100.3/24"
        gateway = "192.168.100.1"
      }
    }
  }

  disk {
    datastore_id = var.proxmox_datastore_name
    file_id      = var.vm_image_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 20
  }

  cpu {
    architecture = "x86_64"
    cores = 1
    type = "host"
  }

  memory {
    dedicated = 1024
  }

  network_device {
    bridge = "vmbr0"
  }

  depends_on = [proxmox_virtual_environment_file.dns_cloud_config]
}

# SSH Public Key
data "local_file" "ssh_public_key" {
    filename = "./id_rsa.pub"
}