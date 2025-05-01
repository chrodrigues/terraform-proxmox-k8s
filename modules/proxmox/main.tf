# Kubernetes Cloud-Init Configuration
resource "proxmox_virtual_environment_file" "k8s_cloud_config" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_name
  node_name    = var.proxmox_node_name

  source_raw {
    data = <<-EOF
    #cloud-config
    disk_setup:
      ephemeral0:
        table_type: mbr
        layout: auto
      /dev/vdb:
        table_type: mbr
        layout: true
        overwrite: false
    fs_setup:
      - label: ephemeral0
        filesystem: ext4
        device: /dev/vdb1
    mounts:
      - [ vdb, /var/openebs/local, ext4, "defaults,nofail", 0, 0 ]
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
          192.168.100.3 bind9-dns-server bind9-dns-server.homelab.local ns1.homelab.local dns.homelab.local homelab.local
          ${format("192.168.100.%d", var.k8s_control_plane_ip_start)} k8s-control-plane-0 k8s-control-plane-0.homelab.local
          %{~ for i in range(1, var.proxmox_number_of_vm_k8s_control_plane) ~}
          ${format("192.168.100.%d", var.k8s_control_plane_ip_start + i)} k8s-control-plane-${i} k8s-control-plane-${i}.homelab.local
          %{~ endfor ~}
          %{~ for i in range(var.proxmox_number_of_vm_k8s_worker_node) ~}
          ${format("192.168.100.%d", var.k8s_worker_ip_start + i)} k8s-worker-${i} k8s-worker-${i}.homelab.local
          %{~ endfor ~}
        permissions: '0644'
      - path: /etc/resolv.conf
        content: |
          nameserver 192.168.100.3
          nameserver 8.8.8.8
          search homelab.local
        permissions: '0644'
      - path: /root/kubeadm-config.yaml
        content: |
          apiVersion: kubeadm.k8s.io/v1beta3
          kind: InitConfiguration
          nodeRegistration:
            name: ${var.proxmox_vm_name_k8s_control_plane}0
          ---
          apiVersion: kubeadm.k8s.io/v1beta3
          kind: ClusterConfiguration
          kubernetesVersion: v1.30.0
          controlPlaneEndpoint: ${format("192.168.100.%d", var.k8s_control_plane_ip_start)}:6443
          networking:
            podSubnet: 10.45.0.0/16
        permissions: '0600'
      - path: /root/calico-custom-resources.yaml
        content: |
          apiVersion: operator.tigera.io/v1
          kind: Installation
          metadata:
            name: default
          spec:
            calicoNetwork:
              ipPools:
              - name: default-ipv4-ippool
                blockSize: 26
                cidr: 10.45.0.0/16
                encapsulation: VXLANCrossSubnet
                natOutgoing: Enabled
                nodeSelector: all()
          ---
          apiVersion: operator.tigera.io/v1
          kind: APIServer
          metadata:
            name: default
          spec: {}
        permissions: '0600'
    runcmd:

      # Set hostname based on VM IP
      - |
        echo "Starting hostname setup" > /tmp/cloud-init.log
        IP_ADDR=$(ip -4 addr show | grep inet | grep -v 127.0.0.1 | head -1 | awk '{print $2}' | cut -d'/' -f1)
        HOSTNAME=""
        %{~ for i in range(var.proxmox_number_of_vm_k8s_control_plane) ~}
        if [ "${format("192.168.100.%d", var.k8s_control_plane_ip_start + i)}" = "$IP_ADDR" ]; then
          HOSTNAME="${var.proxmox_vm_name_k8s_control_plane}${i}"
        fi
        %{~ endfor ~}
        %{~ for i in range(var.proxmox_number_of_vm_k8s_worker_node) ~}
        if [ "${format("192.168.100.%d", var.k8s_worker_ip_start + i)}" = "$IP_ADDR" ]; then
          HOSTNAME="${var.proxmox_vm_name_k8s_worker_node}${i}"
        fi
        %{~ endfor ~}
        if [ -n "$HOSTNAME" ]; then
          echo "Setting hostname to $HOSTNAME" >> /tmp/cloud-init.log
          hostnamectl set-hostname "$HOSTNAME"
          echo "Adding self-referential entry to /etc/hosts" >> /tmp/cloud-init.log
          echo "$IP_ADDR $HOSTNAME $HOSTNAME.homelab.local" >> /etc/hosts
          echo "Hostname set successfully" >> /tmp/cloud-init.log
        else
          echo "Failed to set hostname: No matching IP for $IP_ADDR" >> /tmp/cloud-init.log
          exit 1
        fi
      # Disable systemd-resolved to prevent overwriting /etc/resolv.conf
      - |
        echo "Disabling systemd-resolved to preserve /etc/resolv.conf" >> /tmp/cloud-init.log
        systemctl disable systemd-resolved >> /tmp/cloud-init.log 2>&1
        systemctl stop systemd-resolved >> /tmp/cloud-init.log 2>&1
      # Prevent DHCP from overwriting /etc/resolv.conf
      - |
        echo "Configuring DHCP to not overwrite /etc/resolv.conf" >> /tmp/cloud-init.log
        echo "supersede domain-name-servers 192.168.100.3, 8.8.8.8;" >> /etc/dhcp/dhclient.conf
        echo "supersede domain-name \"homelab.local\";" >> /etc/dhcp/dhclient.conf
      # Verify /etc/resolv.conf
      - |
        echo "Verifying /etc/resolv.conf contents" >> /tmp/cloud-init.log
        cat /etc/resolv.conf >> /tmp/cloud-init.log
      # Install prerequisites
      - |
        echo "Installing prerequisites" >> /tmp/cloud-init.log
        apt update >> /tmp/cloud-init.log 2>&1 || { echo "apt update failed" >> /tmp/cloud-init.log; exit 1; }
        apt install -y apt-transport-https ca-certificates curl gnupg net-tools jq python3 qemu-guest-agent >> /tmp/cloud-init.log 2>&1 || { echo "apt install failed" >> /tmp/cloud-init.log; exit 1; }
        systemctl enable qemu-guest-agent >> /tmp/cloud-init.log 2>&1
        systemctl start qemu-guest-agent >> /tmp/cloud-init.log 2>&1
        timedatectl set-timezone America/Toronto >> /tmp/cloud-init.log 2>&1
      # Install CNI plugins manually
      - |
        echo "Installing CNI plugins" >> /tmp/cloud-init.log
        CNI_VERSION="v1.5.1"
        mkdir -p /opt/cni/bin
        curl -L "https://github.com/containernetworking/plugins/releases/download/$CNI_VERSION/cni-plugins-linux-amd64-$CNI_VERSION.tgz" | tar -C /opt/cni/bin -xz >> /tmp/cloud-init.log 2>&1 || { echo "Failed to install CNI plugins" >> /tmp/cloud-init.log; exit 1; }
        ls /opt/cni/bin >> /tmp/cloud-init.log 2>&1
      # Configure kernel modules
      - |
        echo "Configuring kernel modules" >> /tmp/cloud-init.log
        cat <<EOM | tee /etc/modules-load.d/k8s.conf
        overlay
        br_netfilter
        EOM
        modprobe overlay >> /tmp/cloud-init.log 2>&1 || { echo "modprobe overlay failed" >> /tmp/cloud-init.log; exit 1; }
        modprobe br_netfilter >> /tmp/cloud-init.log 2>&1 || { echo "modprobe br_netfilter failed" >> /tmp/cloud-init.log; exit 1; }
      # Configure sysctl settings
      - |
        echo "Configuring sysctl settings" >> /tmp/cloud-init.log
        cat <<EOM | tee /etc/sysctl.d/k8s.conf
        net.bridge.bridge-nf-call-iptables  = 1
        net.bridge.bridge-nf-call-ip6tables = 1
        net.ipv4.ip_forward                 = 1
        EOM
        sysctl --system >> /tmp/cloud-init.log 2>&1 || { echo "sysctl failed" >> /tmp/cloud-init.log; exit 1; }
      # Install containerd
      - |
        echo "Installing containerd" >> /tmp/cloud-init.log
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >> /tmp/cloud-init.log 2>&1 || { echo "containerd key setup failed" >> /tmp/cloud-init.log; exit 1; }
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list
        apt update >> /tmp/cloud-init.log 2>&1 || { echo "apt update for containerd failed" >> /tmp/cloud-init.log; exit 1; }
        apt install -y containerd.io=1.7.27-1 >> /tmp/cloud-init.log 2>&1 || { echo "containerd install failed" >> /tmp/cloud-init.log; exit 1; }
        containerd config default | tee /etc/containerd/config.toml >> /tmp/cloud-init.log 2>&1
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml >> /tmp/cloud-init.log 2>&1
        systemctl restart containerd >> /tmp/cloud-init.log 2>&1 || { echo "containerd restart failed" >> /tmp/cloud-init.log; exit 1; }
        systemctl enable containerd >> /tmp/cloud-init.log 2>&1
      # Install Kubernetes components
      - |
        echo "Installing Kubernetes components" >> /tmp/cloud-init.log
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg >> /tmp/cloud-init.log 2>&1 || { echo "Kubernetes key setup failed" >> /tmp/cloud-init.log; exit 1; }
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
        apt update >> /tmp/cloud-init.log 2>&1 || { echo "apt update for Kubernetes failed" >> /tmp/cloud-init.log; exit 1; }
        apt install -y kubelet=1.30.0-1.1 kubeadm=1.30.0-1.1 kubectl=1.30.0-1.1 >> /tmp/cloud-init.log 2>&1 || { echo "Kubernetes install failed" >> /tmp/cloud-init.log; exit 1; }
        apt-mark hold kubelet kubeadm kubectl >> /tmp/cloud-init.log 2>&1
        systemctl enable --now kubelet >> /tmp/cloud-init.log 2>&1
      # Test DNS resolution
      - |
        echo "Testing DNS resolution" >> /tmp/cloud-init.log
        ping -c 1 192.168.100.3 >> /tmp/cloud-init.log 2>&1 || { echo "DNS server unreachable" >> /tmp/cloud-init.log; exit 1; }
        nslookup ns1.homelab.local 192.168.100.3 >> /tmp/cloud-init.log 2>&1 || { echo "DNS resolution failed for ns1.homelab.local" >> /tmp/cloud-init.log; }
      # Open firewall for HTTP server (control plane only)
      - |
        if [ "${var.proxmox_vm_name_k8s_control_plane}0" = "$(hostname)" ]; then
          echo "Configuring firewall for HTTP server" >> /tmp/cloud-init.log
          ufw allow 8000/tcp >> /tmp/cloud-init.log 2>&1 || { echo "Failed to configure UFW" >> /tmp/cloud-init.log; exit 1; }
        fi
      # Initialize cluster on first control plane node
      - |
        if [ "${var.proxmox_vm_name_k8s_control_plane}0" = "$(hostname)" ]; then
          echo "Initializing control plane" >> /tmp/cloud-init.log
          kubeadm init --config=/root/kubeadm-config.yaml --upload-certs >> /tmp/kubeadm-init.log 2>&1
          if [ $? -ne 0 ]; then
            echo "kubeadm init failed" >> /tmp/cloud-init.log
            exit 1
          fi
          mkdir -p /home/${var.proxmox_vm_user}/.kube >> /tmp/cloud-init.log 2>&1
          cp /etc/kubernetes/admin.conf /home/${var.proxmox_vm_user}/.kube/config >> /tmp/cloud-init.log 2>&1
          chown ${var.proxmox_vm_user}:${var.proxmox_vm_user} /home/${var.proxmox_vm_user}/.kube/config >> /tmp/cloud-init.log 2>&1
          kubeadm token create --print-join-command > /tmp/k8s-join-token 2>> /tmp/cloud-init.log
          chmod 644 /tmp/k8s-join-token >> /tmp/cloud-init.log 2>&1
          kubeadm init phase upload-certs --upload-certs | grep -o '[0-9a-f]\{64\}' > /tmp/k8s-cert-key 2>> /tmp/cloud-init.log
          chmod 644 /tmp/k8s-cert-key >> /tmp/cloud-init.log 2>&1
          echo "Starting HTTP server for join token" >> /tmp/cloud-init.log
          for attempt in $(seq 1 5); do
            pkill -f "python3 -m http.server" 2>/dev/null
            python3 -m http.server 8000 --directory /tmp >> /tmp/http-server.log 2>&1 &
            sleep 10
            if netstat -tulnp | grep :8000; then
              echo "HTTP server started successfully on attempt $attempt" >> /tmp/cloud-init.log
              break
            fi
            echo "Retry $attempt: Failed to start HTTP server" >> /tmp/cloud-init.log
          done
          if ! netstat -tulnp | grep :8000; then
            echo "HTTP server failed to start after 5 attempts" >> /tmp/cloud-init.log
            exit 1
          fi
          export KUBECONFIG=/home/${var.proxmox_vm_user}/.kube/config
          # Wait for API server to be ready before installing Calico
          echo "Waiting for Kubernetes API server to be ready" >> /tmp/cloud-init.log
          for attempt in $(seq 1 20); do
            if kubectl get nodes > /dev/null 2>&1; then
              echo "Kubernetes API server is ready" >> /tmp/cloud-init.log
              break
            fi
            echo "Retry $attempt: Waiting for API server to be ready" >> /tmp/cloud-init.log
            sleep 30
          done
          if ! kubectl get nodes > /dev/null 2>&1; then
            echo "Kubernetes API server not ready after 10 minutes" >> /tmp/cloud-init.log
            exit 1
          fi
          # Install Calico
          echo "Installing Calico CRD CNI" >> /tmp/cloud-init.log
          kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml --server-side >> /tmp/cloud-init.log 2>&1 || { echo "Failed to apply tigera-operator.yaml" >> /tmp/cloud-init.log; exit 1; }
          # Wait to install calico
          echo "Waiting 30 seconds before installing Calico CNI" >> /tmp/cloud-init.log
          sleep 30
          echo "Installing Calico CNI" >> /tmp/cloud-init.log
          kubectl apply -f /root/calico-custom-resources.yaml --server-side >> /tmp/cloud-init.log 2>&1 || { echo "Failed to apply calico-custom-resources.yaml" >> /tmp/cloud-init.log; exit 1; }
          # Wait for Calico operator to be ready
          echo "Waiting for Calico operator to be ready" >> /tmp/cloud-init.log
          for attempt in $(seq 1 20); do
            if kubectl -n tigera-operator get pods --no-headers 2>/dev/null | grep -v "Completed" | grep "Running" | wc -l | grep -q "1"; then
              echo "Calico operator is ready" >> /tmp/cloud-init.log
              break
            fi
            echo "Retry $attempt: Waiting for Calico operator to be ready" >> /tmp/cloud-init.log
            sleep 30
          done
          if ! kubectl -n tigera-operator get pods --no-headers 2>/dev/null | grep -v "Completed" | grep "Running" | wc -l | grep -q "1"; then
            echo "Calico operator not ready after 10 minutes" >> /tmp/cloud-init.log
            kubectl -n tigera-operator get pods >> /tmp/cloud-init.log 2>&1
            exit 1
          fi
          # Wait for worker nodes to be ready and label them
          for attempt in $(seq 1 10); do
            echo "Retry $attempt: Checking worker nodes readiness" >> /tmp/cloud-init.log
            WORKER_NODES=$(kubectl get node | grep -E 'k8s-worker-[0-9]+' | wc -l)
            WORKER_NODES_STATUS=$(kubectl get node | grep -E 'k8s-worker-[0-9]+' | grep Ready | wc -l)
            EXPECTED_NODES=${var.proxmox_number_of_vm_k8s_worker_node} >> /tmp/cloud-init.log
            echo "Number of expected nodes: echo $EXPECTED_NODES"
            if [ "$WORKER_NODES" -eq "$EXPECTED_NODES" ] && [ "$WORKER_NODES_STATUS" -eq "$EXPECTED_NODES" ]; then
              echo "All $EXPECTED_NODES worker nodes are ready, labeling with role=worker" >> /tmp/cloud-init.log
              %{~ for i in range(var.proxmox_number_of_vm_k8s_worker_node) ~}
              kubectl label nodes k8s-worker-${i} node-role.kubernetes.io/worker=worker --overwrite >> /tmp/cloud-init.log 2>&1
              %{~ endfor ~}
              break
            else
              echo "Not all worker nodes are ready (Detected: $WORKER_NODES/$EXPECTED_NODES, Ready: $WORKER_NODES_STATUS/$EXPECTED_NODES)" >> /tmp/cloud-init.log
              if [ "$attempt" -eq 10 ]; then
                echo "Failed to label worker nodes after 10 attempts" >> /tmp/cloud-init.log
                exit 1
              fi
            fi
            echo "Sleeping for 30 seconds" >> /tmp/cloud-init.log
            sleep 30
          done
        fi
      # Join additional control plane nodes
      - |
        %{~ for i in range(1, var.proxmox_number_of_vm_k8s_control_plane) ~}
        if [ "${var.proxmox_vm_name_k8s_control_plane}${i}" = "$(hostname)" ]; then
          echo "Joining control plane node ${var.proxmox_vm_name_k8s_control_plane}${i}" >> /tmp/cloud-init.log
          echo "Waiting for control plane HTTP server to be ready" >> /tmp/cloud-init.log
          sleep 120
          for attempt in $(seq 1 10); do
            JOIN_CMD=$(curl -v http://${format("192.168.100.%d", var.k8s_control_plane_ip_start)}:8000/k8s-join-token > /tmp/curl-join.log 2>&1)
            if [ -n "$JOIN_CMD" ]; then
              echo "Fetched join command: $JOIN_CMD" >> /tmp/cloud-init.log
              break
            fi
            echo "Retry $attempt: Failed to fetch join token, see /tmp/curl-join.log for details" >> /tmp/cloud-init.log
            sleep 30
          done
          if [ -z "$JOIN_CMD" ]; then
            echo "Falling back to wget for fetching join token" >> /tmp/cloud-init.log
            JOIN_CMD=$(wget -q -O - http://${format("192.168.100.%d", var.k8s_control_plane_ip_start)}:8000/k8s-join-token 2>> /tmp/cloud-init.log)
            if [ -n "$JOIN_CMD" ]; then
              echo "Fetched join command using wget: $JOIN_CMD" >> /tmp/cloud-init.log
            else
              echo "Failed to fetch join token after 10 attempts, even with wget" >> /tmp/cloud-init.log
              exit 1
            fi
          fi
          CERT_KEY=$(curl -v http://${format("192.168.100.%d", var.k8s_control_plane_ip_start)}:8000/k8s-cert-key > /tmp/curl-cert.log 2>&1)
          if [ -z "$CERT_KEY" ]; then
            echo "Failed to fetch certificate key, see /tmp/curl-cert.log for details" >> /tmp/cloud-init.log
            exit 1
          fi
          sh -c "$JOIN_CMD --control-plane --certificate-key $CERT_KEY" >> /tmp/cloud-init.log 2>&1
          if [ $? -ne 0 ]; then
            echo "kubeadm join failed for control plane" >> /tmp/cloud-init.log
            exit 1
          fi
        fi
        %{~ endfor ~}
      # Join worker nodes
      - |
        %{~ for i in range(var.proxmox_number_of_vm_k8s_worker_node) ~}
        if [ "${var.proxmox_vm_name_k8s_worker_node}${i}" = "$(hostname)" ]; then
          echo "Joining worker node ${var.proxmox_vm_name_k8s_worker_node}${i}" >> /tmp/cloud-init.log
          echo "Waiting for control plane HTTP server to be ready" >> /tmp/cloud-init.log
          sleep 120
          for attempt in $(seq 1 10); do
            JOIN_CMD=$(wget -q -O - http://${format("192.168.100.%d", var.k8s_control_plane_ip_start)}:8000/k8s-join-token 2>> /tmp/cloud-init.log)
            if [ -n "$JOIN_CMD" ]; then
              echo "Fetched join command: $JOIN_CMD" >> /tmp/cloud-init.log
              break
            fi
            echo "Retry $attempt: Failed to fetch join token, see /tmp/curl-join.log for details" >> /tmp/cloud-init.log
            sleep 30
          done
          if [ -z "$JOIN_CMD" ]; then
            echo "Falling back to curl for fetching join token" >> /tmp/cloud-init.log
            JOIN_CMD=$(curl -v http://${format("192.168.100.%d", var.k8s_control_plane_ip_start)}:8000/k8s-join-token 2>> /tmp/curl-join.log 2>&1)

            if [ -n "$JOIN_CMD" ]; then
              echo "Fetched join command using curl: $JOIN_CMD" >> /tmp/cloud-init.log
            else
              echo "Failed to fetch join token after 10 attempts, even with curl" >> /tmp/cloud-init.log
              exit 1
            fi
          fi
          sh -c "$JOIN_CMD" >> /tmp/cloud-init.log 2>&1
          if [ $? -ne 0 ]; then
            echo "kubeadm join failed for worker node" >> /tmp/cloud-init.log
            exit 1
          fi
        fi
        %{~ endfor ~}
      # Mark setup complete
      - echo "Kubernetes setup complete" > /tmp/cloud-config.done
    EOF

    file_name = "cloud-config.yaml"
  }
}

# Existing Kubernetes Control Plane VMs
resource "proxmox_virtual_environment_vm" "k8s-control-plane" {
    count      = var.proxmox_number_of_vm_k8s_control_plane
    name       = format("%s%s", var.proxmox_vm_name_k8s_control_plane, count.index)
    node_name  = var.proxmox_node_name
    stop_on_destroy = true

    agent {
      enabled = true
    }

    initialization {
      user_data_file_id = proxmox_virtual_environment_file.k8s_cloud_config.id

      ip_config {
        ipv4 {
          address = format("192.168.100.%d/24", count.index + var.k8s_control_plane_ip_start)
          gateway = "192.168.100.1"
        }
      }
    }

    disk {
      datastore_id = var.proxmox_datastore_name
      file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
      interface    = "virtio0"
      iothread     = true
      discard      = "on"
      size         = 40
    }

    cpu {
      architecture = "x86_64"
      cores = 2
      type = "host"
    }

    memory {
      dedicated = 4096
    }

    network_device {
      bridge = "vmbr0"
    }

    depends_on = [proxmox_virtual_environment_file.k8s_cloud_config]
}

# Existing Kubernetes Worker Nodes
resource "proxmox_virtual_environment_vm" "k8s-worker-node" {
    count      = var.proxmox_number_of_vm_k8s_worker_node
    name       = format("%s%s", var.proxmox_vm_name_k8s_worker_node, count.index)
    node_name  = var.proxmox_node_name
    stop_on_destroy = true

    agent {
      enabled = true
    }

    initialization {
      user_data_file_id = proxmox_virtual_environment_file.k8s_cloud_config.id

      ip_config {
        ipv4 {
          address = format("192.168.100.%d/24", count.index + var.k8s_worker_ip_start)
          gateway = "192.168.100.1"
        }
      }
    }

    disk {
      datastore_id = var.proxmox_datastore_name
      file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
      interface    = "virtio0"
      iothread     = true
      discard      = "on"
      size         = 30
    }

    disk {
      datastore_id = var.proxmox_datastore_name
      interface    = "virtio1"
      iothread     = true
      discard      = "on"
      size         = 100
    }

    cpu {
      architecture = "x86_64"
      cores = 4
      type = "host"
    }

    memory {
      dedicated = 6144
    }

    network_device {
      bridge = "vmbr0"
    }

    depends_on = [proxmox_virtual_environment_vm.k8s-control-plane]
}

# Ubuntu Cloud Image
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
    content_type = "iso"
    datastore_id = var.proxmox_datastore_name
    node_name    = var.proxmox_node_name
    upload_timeout = 2500

    url = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
}

# SSH Public Key
data "local_file" "ssh_public_key" {
    filename = "./id_rsa.pub"
}

#TODO: Prepare one node to be the "IA node"
#TODO: https://hub.docker.com/r/ollama/ollama