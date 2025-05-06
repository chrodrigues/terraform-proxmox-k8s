Terraform Proxmox Kubernetes
This project automates the deployment of a Kubernetes cluster on Proxmox using Terraform. Ideal for homelabs, development, or testing environments.
🛠️ Tech Stack

Terraform: Infra as code, provisioning VMs on Proxmox.
Proxmox VE: Hypervisor for running our VMs.
Kubernetes (v1.30): Kubeadm for cluster setup, Calico for networking.
BIND9: Optional DNS server for homelab.local resolution.
Ubuntu 22.04: Base image for all VMs.
containerd: Container runtime for K8s.

📋 Prerequisites
Before you kick things off, make sure you’ve got:

Proxmox VE 7.0+ up and running.
Terraform 1.3+ installed locally.
SSH key pair (put your public key in [id_rsa.pub](id_rsa.pub)).
Proxmox API access with a user and password (or token, but we’re using password here).
A network bridge (vmbr0) configured in Proxmox.
Enough resources for VMs (e.g., 1 DNS VM, 1+ control plane, 3+ worker nodes).

🚀 Getting Started
1. Clone the Repo
Grab the code and hop into the directory:
git clone https://github.com/chrodrigues/terraform-proxmox-k8s
cd terraform-proxmox-k8s

2. Set Up Your Variables
You’ll need to configure variables for Proxmox and the K8s cluster. Create a file called secret.auto.tfvars (it’s gitignored, so your secrets are safe). Here’s an example:
# Proxmox connection
proxmox_endpoint = "https://192.168.1.100:8006/api2/json"
proxmox_user_name = "root@pam"
proxmox_user_password = "your-super-secret-password"

# VM user
proxmox_vm_user = "Ubuntu"
proxmox_vm_password = "your-vm-password"

# Cluster config
proxmox_node_name = "proxmox"
proxmox_datastore_name = "local"
proxmox_number_of_vm_k8s_control_plane = "1"
proxmox_number_of_vm_k8s_worker_node = "3"
k8s_control_plane_ip_start = "50"  # First control plane IP: 192.168.100.50
k8s_worker_ip_start = "60"        # First worker IP: 192.168.100.60

Check out all variables in [variables.tf](variables.tf) for defaults and descriptions. Key ones to set:

proxmox_endpoint: Your Proxmox API URL (e.g., https://<proxmox-ip>:8006/api2/json).
proxmox_user_name and proxmox_user_password: API credentials.
proxmox_vm_user and proxmox_vm_password: User for SSH into VMs.
k8s_control_plane_ip_start and k8s_worker_ip_start: Starting IPs for control plane and worker nodes (e.g., 50 for 192.168.100.50).
proxmox_number_of_vm_k8s_control_plane and proxmox_number_of_vm_k8s_worker_node: Number of control plane and worker nodes.

3. Optional: DNS Server
This project includes a BIND9 DNS server module that sets up a VM at 192.168.100.3 for homelab.local. It’s super handy for local DNS resolution, but you don’t have to use it if you’ve got your own DNS server.
If you skip the DNS module:

Comment out the bind9_server module in [main.tf](main.tf):
# module "bind9_server" { ... }


Update the /etc/resolv.conf in the Kubernetes module’s cloud-init config ([modules/proxmox/main.tf](modules/proxmox/main.tf)). Replace:
nameserver 192.168.100.3

with your DNS server’s IP, like:
nameserver 192.168.1.1  # Your DNS server


Make sure your DNS server resolves homelab.local or adjust the /etc/hosts in the same file to match your domain.


If you use the DNS module:

It auto-configures a VM with BIND9, sets up forward and reverse zones for homelab.local, and uses Google’s DNS (8.8.8.8, 8.8.4.4) as forwarders.
No extra config needed unless you want to tweak the zones (see [modules/bind9_dnsserver/main.tf](modules/bind9_dnsserver/main.tf)).

4. Deploy the Cluster
Time to fire it up! Run these commands:
terraform init
terraform plan  # Check what’s gonna happen
terraform apply --auto-approve

This will:

Spin up a DNS VM (if enabled) at 192.168.100.3.
Create control plane VMs (e.g., k8s-control-plane-0 at 192.168.100.50) and worker nodes (e.g., k8s-worker-0 at 192.168.100.60).
Configure each VM with cloud-init to install containerd, kubeadm, and Calico CNI.
Bootstrap the K8s cluster using kubeadm, with the first control plane node running a temporary HTTP server (port 8000) to share the join token.

5. Access Your Cluster
Once terraform apply finishes (takes ~7-12 minutes), SSH into the first control plane node (k8s-control-plane-0):
ssh ubuntu@192.168.100.50

Check the cluster:
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl get nodes

You should see your control plane and worker nodes in Ready state. The kubeconfig is already set up at /home/ubuntu/.kube/config on the first control plane node.
🐛 Debugging Tips
If something goes wonky, don’t panic! Here’s how to troubleshoot:

Check Terraform logs: Look at the output of terraform apply for errors (e.g., wrong Proxmox credentials).

VM logs: SSH into a VM (e.g., ssh ubuntu@192.168.100.50) and check:

/tmp/cloud-init.log: Main log for Kubernetes setup (control plane/worker nodes).
/tmp/dns-config.log: DNS server setup log (if using BIND9 module).
/tmp/kubeadm-init.log: Kubeadm initialization log on the first control plane node.
/tmp/http-server.log: HTTP server logs for join token sharing.


DNS issues:

Run nslookup ns1.homelab.local 192.168.100.3 on a VM to test DNS resolution.
If using your own DNS, verify /etc/resolv.conf has the right nameserver.


Kubernetes issues:

Check kubectl get pods -A to see if Calico or other pods are crashing.
Run journalctl -u kubelet on a node to debug kubelet issues.


Proxmox console: Use the Proxmox UI to check VM status or console output if SSH fails.

HTTP server woes: If nodes can’t join, ensure port 8000 is open on the first control plane node (ufw allow 8000/tcp) and check /tmp/k8s-join-token.


If you’re stuck, open an issue or ping me!
📂 Project Structure
Here’s a quick rundown of the repo’s layout:
Root:

[main.tf](main.tf): Calls the bind9_server and proxmox modules.
[provider.tf](provider.tf): Configures the Proxmox provider.
[variables.tf](variables.tf): Defines all variables (with defaults).
[secret.auto.tfvars](secret.auto.tfvars): Your sensitive creds (gitignored for safety).
[id_rsa.pub](id_rsa.pub): SSH public key for VM access.
[LICENSE](LICENSE): License file (consider using MIT if not set).
.terraform/, terraform.tfstate, etc.: Auto-generated by Terraform.

Modules:

[modules/bind9_dnsserver/](modules/bind9_dnsserver/): Sets up the BIND9 DNS server.
[modules/proxmox/](modules/proxmox/): Deploys the Kubernetes cluster VMs.
[modules/helm/](modules/helm/): Future Helm module for Prometheus/Grafana (commented out for now).

The [.gitignore](.gitignore) ensures sensitive files like secret.auto.tfvars and Terraform state aren’t versioned. Keep it that way for security! 🔒
📊 Architecture
Here’s the big picture:

DNS VM (optional): Runs BIND9 at 192.168.100.3, resolving homelab.local.
Control Plane VMs: Run kubeadm to bootstrap the cluster, starting at 192.168.100.50.
Worker Nodes: Join the cluster, starting at 192.168.100.60, with extra disk for OpenEBS.
Networking: Calico CNI with pod subnet 10.45.0.0/16, VXLAN encapsulation.

🔮 Coming Soon

Helm Charts: There’s a TODO in [main.tf](main.tf) to add Helm for deploying Prometheus and Grafana (with OpenEBS storage). Stay tuned for monitoring goodness! 📈
IA Node: Planning to dedicate a node for AI workloads (maybe with Ollama, see the TODO).

📬 Contributing
Got ideas? Found a bug? Open an issue or submit a PR. Check our [guidelines](CONTRIBUTING.md) for the deets.
