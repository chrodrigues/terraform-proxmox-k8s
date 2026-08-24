.PHONY: all infra cluster plan destroy kubeconfig

# Full deploy: create the VMs, then bootstrap Kubernetes
all: infra cluster

infra:
	terraform init
	terraform apply -auto-approve

plan:
	terraform init
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
