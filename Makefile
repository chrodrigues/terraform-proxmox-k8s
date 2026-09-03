.PHONY: all infra cluster plan destroy kubeconfig

# Terraform state lives outside the repo so CI and manual runs share it
STATE ?= $(HOME)/.terraform-proxmox-k8s/terraform.tfstate
TF_INIT = terraform init -input=false -reconfigure -backend-config="path=$(STATE)"

# Full deploy: create the VMs, then bootstrap Kubernetes
all: infra cluster

infra:
	$(TF_INIT)
	terraform apply -auto-approve

plan:
	$(TF_INIT)
	terraform plan

cluster:
	cd ansible && ansible-playbook site.yml

destroy:
	terraform destroy -auto-approve

# Fetch the cluster admin kubeconfig to ansible/artifacts/kubeconfig
kubeconfig:
	cd ansible && ansible 'control_plane[0]' --become -m ansible.builtin.fetch \
		-a "src=/etc/kubernetes/admin.conf dest=artifacts/kubeconfig flat=true"
	@echo ""
	@echo "Run: export KUBECONFIG=$(CURDIR)/ansible/artifacts/kubeconfig"
