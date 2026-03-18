# Makefile — proxmox-iac
.PHONY: help packer-init packer-validate packer-build tf-init tf-plan tf-apply tf-destroy

PACKER_DIR     = packer
PACKER_VARS    = variables.pkrvars.hcl
TF_ENV         = environments/lab

# Affiche l'aide par défaut quand on tape juste "make"
help:
	@echo ""
	@echo "  proxmox-iac — commandes disponibles"
	@echo ""
	@echo "  Packer"
	@echo "    make packer-init       Initialise les plugins Packer"
	@echo "    make packer-validate   Valide la syntaxe du template"
	@echo "    make packer-build      Construit le template dans Proxmox"
	@echo ""
	@echo "  Terraform"
	@echo "    make tf-init           Initialise les providers"
	@echo "    make tf-plan           Prévisualise les changements"
	@echo "    make tf-apply          Déploie les VMs"
	@echo "    make tf-destroy        Supprime toutes les VMs"
	@echo ""

# ── Packer ────────────────────────────────────────────────
packer-init:
	cd $(PACKER_DIR) && packer init ubuntu.pkr.hcl

packer-validate:
	cd $(PACKER_DIR) && packer validate -var-file="$(PACKER_VARS)" ubuntu.pkr.hcl

packer-build:
	cd $(PACKER_DIR) && packer build -var-file="$(PACKER_VARS)" ubuntu.pkr.hcl

# ── Terraform ─────────────────────────────────────────────
tf-init:
	cd $(TF_ENV) && terraform init

tf-plan:
	cd $(TF_ENV) && terraform plan

tf-apply:
	cd $(TF_ENV) && terraform apply

tf-destroy:
	cd $(TF_ENV) && terraform destroy