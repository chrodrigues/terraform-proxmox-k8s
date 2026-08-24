# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- added Ansible playbook (`ansible/site.yml`) with roles for DNS (BIND9), node preparation (containerd, kubeadm), control plane bootstrap (kubeadm init + Calico) and worker join
- added automatic Ansible inventory and variables generation from Terraform (`ansible/inventory/hosts.yml` and `ansible/group_vars/all/terraform.yml`)
- added DNS A/PTR records for every cluster node in the BIND9 zones, generated from the inventory
- added `Makefile` with `make all` (VMs + cluster), `make infra`, `make cluster` and `make destroy`
- added variables for network prefix, gateway, DNS server IP, domain, timezone and VM sizing (cores, memory, disks)
- added `outputs.tf` with node IPs and the next-step hint after `terraform apply`
- added `proxmox_vm_datastore_name` variable so VM disks can live on a different datastore (e.g. `local-lvm`) than snippets/ISO (`local`)
- added `ssh_public_key_file` / `ssh_private_key_file` variables to use existing SSH keys (e.g. `~/.ssh/id_rsa`)
- added kubeconfig fetch at the end of the control plane play (`ansible/artifacts/kubeconfig`, gitignored) for use by pipelines and local kubectl
- added `make kubeconfig` target to fetch the cluster admin kubeconfig on demand

### Changed

- changed cluster bootstrap from cloud-init `runcmd` scripts to idempotent Ansible roles; cloud-init now only creates the user, SSH key, qemu-guest-agent and the OpenEBS data disk
- changed join token and certificate distribution to Ansible delegation instead of a temporary HTTP server on port 8000
- changed count and IP-start variables from `string` to `number`
- changed VM resources from `count` to `for_each` keyed by VM name
- changed hostname assignment from an IP-matching boot script to the Ansible inventory name

### Fixed

- fixed the certificate-key fetch for additional control plane nodes (the old `curl -v ... > file` redirect always produced an empty variable, so extra control planes could never join)
- fixed the OpenEBS data disk mount device (`vdb` -> `vdb1`, the actual formatted partition)

### Removed

- removed the temporary HTTP server (port 8000) that exposed the join token and certificate key to the whole network
- removed `provider` blocks from modules (provider is configured once at the root)
- removed unused variables (`proxmox_vm_password`, Grafana/Prometheus variables belonging to the commented-out helm module)
- removed the manual CNI plugins download (the Calico operator installs its own CNI binaries)
