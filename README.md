# Terraform Proxmox Kubernetes

This project automates the deployment of a Kubernetes cluster on Proxmox using **Terraform** (infrastructure) and **Ansible** (cluster bootstrap). Ideal for homelabs, development, or testing environments.

**Why the split?** Terraform is great at creating VMs, but terrible at knowing whether a 10-minute bootstrap script inside cloud-init actually worked. Ansible is idempotent: if something fails halfway, just run the playbook again and it picks up where it left off — no need to destroy and recreate VMs.

## 🛠️ Tech Stack

- **Terraform**: Provisions the VMs on Proxmox and generates the Ansible inventory.
- **Ansible**: Installs and bootstraps the cluster (DNS, containerd, kubeadm, Calico).
- **Proxmox VE**: Hypervisor for running our VMs.
- **Kubernetes (v1.30)**: Kubeadm for cluster setup, Calico for networking.
- **BIND9**: DNS server for `homelab.local` resolution (forward + reverse zones with a record for every node).
- **Ubuntu 22.04**: Base image for all VMs.
- **containerd**: Container runtime for K8s.

## 📋 Prerequisites

Before you kick things off, make sure you’ve got:

- Proxmox VE 7.0+ up and running.
- Terraform 1.3+ installed locally.
- Ansible 2.14+ installed locally (`pipx install ansible` or your package manager).
- SSH key pair: point `ssh_public_key_file` / `ssh_private_key_file` at your keys (e.g. `~/.ssh/id_rsa.pub`), or drop them in the repo root as `id_rsa.pub` / `id_rsa` (the private key is gitignored).
- The snippets datastore needs the `snippets` content type enabled (Proxmox UI: Datacenter → Storage → local → Content).
- Proxmox API access with a user and password.
- A network bridge (`vmbr0`) configured in Proxmox.
- Enough resources for VMs (e.g., 1 DNS VM, 1+ control plane, 3+ worker nodes).

## 🚀 Getting Started

### 1. Clone the Repo

```bash
git clone https://github.com/chrodrigues/terraform-proxmox-k8s
cd terraform-proxmox-k8s
```

### 2. Set Up Your Variables

Create a file called `secret.auto.tfvars` (it’s gitignored, so your secrets are safe). Here’s an example:

```hcl
# Proxmox connection
proxmox_endpoint      = "https://192.168.1.100:8006/api2/json"
proxmox_user_name     = "root@pam"
proxmox_user_password = "your-super-secret-password"

# VM user (also used by Ansible over SSH)
proxmox_vm_user = "ubuntu"

# SSH keys (defaults: ./id_rsa.pub and ./id_rsa in the repo root)
ssh_public_key_file  = "~/.ssh/id_rsa.pub"
ssh_private_key_file = "~/.ssh/id_rsa"

# Cluster config
proxmox_node_name                      = "proxmox"
proxmox_datastore_name                 = "local"     # snippets + cloud image (enable 'snippets' content on it)
proxmox_vm_datastore_name              = "local-lvm" # VM disks
proxmox_number_of_vm_k8s_control_plane = 1
proxmox_number_of_vm_k8s_worker_node   = 3

# Network (defaults shown - change to match your LAN)
network_prefix             = "192.168.100"
network_gateway            = "192.168.100.1"
dns_server_ip              = "192.168.100.3"
k8s_control_plane_ip_start = 50 # first control plane IP: 192.168.100.50
k8s_worker_ip_start        = 60 # first worker IP: 192.168.100.60
```

Check out all variables in [variables.tf](variables.tf) for defaults and descriptions (domain, timezone, VM sizing, etc.).

### 3. Deploy Everything

```bash
make all
```

That’s it. Under the hood this runs two steps, which you can also run separately:

```bash
# Step 1: create the VMs (DNS, control plane, workers)
terraform init
terraform apply -auto-approve

# Step 2: bootstrap the cluster (DNS zones, containerd, kubeadm init/join, Calico)
cd ansible
ansible-playbook site.yml
```

`terraform apply` also generates the Ansible inventory (`ansible/inventory/hosts.yml`) and shared variables (`ansible/group_vars/all/terraform.yml`) from your Terraform values — single source of truth, nothing to copy by hand.

**Something failed halfway?** Just run `ansible-playbook site.yml` again. It’s idempotent — it skips what’s done and retries what isn’t.

### 4. Access Your Cluster

The deploy drops the cluster admin kubeconfig at `ansible/artifacts/kubeconfig` (gitignored). Use it straight from your machine:

```bash
export KUBECONFIG=$PWD/ansible/artifacts/kubeconfig
kubectl get nodes
```

Need to fetch it again later (or on another operator's machine)? `make kubeconfig`.

You can also SSH into the first control plane node (`ssh ubuntu@192.168.100.50`) — the kubeconfig is set up there at `/home/<vm_user>/.kube/config`.

## 🌐 DNS

The BIND9 module sets up a DNS VM (default `192.168.100.3`) with forward and reverse zones for `homelab.local`, including an A and PTR record for **every** cluster node (generated from the inventory). Upstream queries are forwarded to Google DNS (`8.8.8.8`, `8.8.4.4`).

Using your own DNS server instead? Comment out the `bind9_server` module in [main.tf](main.tf), remove the `dns` play from [ansible/site.yml](ansible/site.yml), and set `resolv_nameservers` in [ansible/group_vars/k8s.yml](ansible/group_vars/k8s.yml) to your server.

## 🐛 Debugging Tips

- **Terraform errors**: usually Proxmox credentials, datastore or node name. Check `terraform plan` output.
- **Ansible errors**: the failing task name tells you exactly what broke. Re-run with more detail:

  ```bash
  ansible-playbook site.yml -v          # verbose
  ansible-playbook site.yml --limit k8s-worker-1   # single host
  ```

- **DNS issues**: `nslookup k8s-worker-0.homelab.local 192.168.100.3` from any VM.
- **Kubernetes issues**:
  - `kubectl get pods -A` to see if Calico or other pods are crashing.
  - `journalctl -u kubelet` on a node to debug kubelet issues.
- **Proxmox console**: Use the Proxmox UI to check VM status or console output if SSH fails.

If you’re stuck, open an issue or ping me!

## 📂 Project Structure

```
├── main.tf                  # Modules + Ansible inventory generation
├── provider.tf              # Proxmox provider config
├── variables.tf             # All variables (with defaults)
├── outputs.tf               # Node IPs + next-step hint
├── Makefile                 # make all / infra / cluster / destroy
├── templates/               # Ansible inventory + vars templates
├── modules/
│   ├── proxmox/             # K8s VMs (minimal cloud-init: user, SSH, agent, data disk)
│   ├── bind9_dnsserver/     # DNS VM (minimal cloud-init)
│   └── helm/                # Future Helm module for Prometheus/Grafana
└── ansible/
    ├── site.yml             # The whole bootstrap, in order
    ├── inventory/hosts.yml  # Generated by Terraform (gitignored)
    ├── group_vars/          # K8s/Calico versions, pod subnet, DNS settings
    └── roles/
        ├── common/          # hostname, /etc/hosts, resolv.conf, base packages
        ├── bind9/           # BIND9 install + zone files from inventory
        ├── kubernetes/      # kernel modules, sysctl, containerd, kubeadm/kubelet
        ├── control_plane/   # kubeadm init, kubeconfig, Calico, extra CP joins
        └── worker/          # kubeadm join + node labels
```

## 📊 Architecture

- **DNS VM**: Runs BIND9 at `192.168.100.3`, resolving `homelab.local`.
- **Control Plane VMs**: kubeadm-bootstrapped, starting at `192.168.100.50`.
- **Worker Nodes**: Join the cluster starting at `192.168.100.60`, with an extra disk mounted at `/var/openebs/local` for OpenEBS.
- **Networking**: Calico CNI with pod subnet `10.45.0.0/16`, VXLAN encapsulation.
- **Join flow**: Ansible generates the join token on the first control plane and delegates it to each node over SSH — no tokens exposed on the network.

## 🔮 Coming Soon

- **Helm Charts**: Prometheus and Grafana (with OpenEBS storage) via the `helm` module. 📈
- **Multi-node Proxmox (HCI)**: spread VMs across a Proxmox cluster with Ceph storage.
- **IA Node**: a dedicated node for AI workloads (maybe with Ollama).

## 📬 Contributing

Got ideas? Found a bug? Open an issue or submit a PR. Check our [guidelines](CONTRIBUTING.md) for the deets.
