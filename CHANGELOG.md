# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- added the `openebs_disk` Ansible role (runs on the workers before they join): mounts the 100 GB data disk at `/var/openebs/local` by filesystem label (`LABEL=openebs`), bind-mounts `/var/local/openebs/localpv-hostpath` (Loki/MinIO LocalPV BasePaths) onto the same disk, and refuses to mount over a directory that already holds data on the root disk
- added the `argocd_bootstrap` Ansible role (runs on the first control plane after the cluster is up): installs helm, clones `chrodrigues/homelab-gitops`, creates the 1Password token and Argo CD repository-credential Secrets, installs Argo CD from the chart with the repo's values and applies the root app-of-apps. Needs the `GITOPS_GITHUB_TOKEN` and `ONEPASSWORD_SA_TOKEN` repository secrets
- added `bind9_extra_records` (group_vars) so the forward zone can carry static A records for cluster services; ships `argocd` and `clara` pointing at the ingress-nginx MetalLB IP (`.201`)
- added GitHub Actions workflow `deploy-cluster` (manual trigger with per-tier node counts) that runs Terraform and Ansible on a self-hosted runner inside the LAN
- added shared Terraform state location (`~/.terraform-proxmox-k8s/terraform.tfstate`) used by both the `make` targets and CI, via `backend "local"` + `-backend-config`
- added a VM-replacement guard to the pipeline: the plan is inspected and the run aborts if existing VMs would be replaced, unless `allow_replace` is checked

### Changed

- changed the default worker VM memory from 6 GB to 12 GB
- changed the default control plane VM memory from 4 GB to 6 GB
- changed the workflow node-count inputs to optional: leaving a count empty keeps the cluster's current size (read from the Terraform state) instead of falling back to a static default

### Fixed

- fixed the OpenEBS data disk (`/dev/vdb`, 100 GB) never being mounted on the workers: cloud-init 26.x wrote the fstab entry with a bare `vdb1` device name that mount cannot resolve, so every LocalPV landed on the 30 GB root disk. The mount is now owned by the `openebs_disk` role instead of cloud-init (changing the cloud-init snippet would replace every VM); existing PVC data was migrated by hand onto the data disk
- fixed the pipeline racing rebooted VMs: a wait_for_connection step now runs between terraform apply and the Ansible playbook

- fixed the argocd_bootstrap role failing with a censored no_log error when the GitOps token secret is missing (an assert now fails fast with a clear message)
- fixed full-cluster VM replacement when Ubuntu republishes the cloud image upstream (`overwrite = false` on the image download)

## [1.0.0] - 2026-08-24

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
