# proxmox-iac

Infrastructure as Code pour déployer et gérer des VMs sur Proxmox.

## Stack technique

| Outil | Rôle |
|---|---|
| **Packer** | Crée les templates de VMs (images de base réutilisables) |
| **Vault** | Stocke les secrets (mots de passe, tokens, clés SSH) |
| **Terraform** | Déploie les VMs à partir des templates |

## Prérequis

- [Packer](https://developer.hashicorp.com/packer/install) >= 1.11
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Vault](https://developer.hashicorp.com/vault/install) >= 1.15
- Un serveur Proxmox VE accessible en réseau

### Installation des outils (Ubuntu/Debian)

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y packer terraform vault
```

## Structure du projet

```
proxmox-iac/
├── packer/                        # Construction des templates
│   ├── ubuntu.pkr.hcl             # Template Ubuntu 22.04
│   ├── variables.pkrvars.hcl      # Variables Packer (⚠️ dans .gitignore)
│   └── scripts/
│       └── setup.sh               # Script de personnalisation de l'image
│
├── modules/
│   └── linux-vm/                  # Module Terraform réutilisable
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── environments/
│   └── lab/                       # Environnement de test
│       ├── providers.tf           # Connexion Proxmox + Vault
│       ├── variables.tf
│       └── main.tf                # Déclaration des VMs
│
├── Makefile                       # Raccourcis de commandes
├── .gitignore
└── README.md
```

## Commandes rapides (Makefile)

Toutes les commandes du projet sont disponibles via `make`. Tape simplement `make` à la racine pour voir la liste complète.

| Commande | Action |
|---|---|
| `make packer-init` | Initialise les plugins Packer |
| `make packer-validate` | Valide la syntaxe du template |
| `make packer-build` | Construit le template dans Proxmox |
| `make tf-init` | Initialise les providers Terraform |
| `make tf-plan` | Prévisualise les changements |
| `make tf-apply` | Déploie les VMs |
| `make tf-destroy` | Supprime toutes les VMs |

## Mise en route

### 1. Créer le template Proxmox avec Packer

```bash
# Copier et remplir le fichier de variables
cp packer/variables.pkrvars.hcl.example packer/variables.pkrvars.hcl
# Éditer variables.pkrvars.hcl avec l'IP et les credentials de ton Proxmox

make packer-init
make packer-validate
make packer-build
```

### 2. Stocker les secrets dans Vault

```bash
export VAULT_ADDR='http://<IP_VAULT>:8200'
export VAULT_TOKEN='<TON_TOKEN>'

vault secrets enable -path=proxmox kv-v2

vault kv put proxmox/terraform \
  username="terraform-prov@pve" \
  password="<MOT_DE_PASSE>" \
  api_url="https://<IP_PROXMOX>:8006/api2/json"

vault kv put proxmox/ssh \
  public_key="$(cat ~/.ssh/id_rsa.pub)"
```

### 3. Déployer les VMs avec Terraform

```bash
export TF_VAR_vault_token="<TON_TOKEN_VAULT>"

make tf-init
make tf-plan
make tf-apply
```

## Sécurité

- Ne jamais committer de secrets → tous les fichiers `*.pkrvars.hcl` et `*.tfvars` sont dans le `.gitignore`
- Les credentials Proxmox et les clés SSH sont gérés exclusivement par Vault
- Le token Vault est passé via variable d'environnement (`TF_VAR_vault_token`), jamais en dur dans le code

## Avancement

- [x] Structure du projet
- [x] Installation des outils
- [x] Makefile
- [ ] Template Packer Ubuntu 22.04
- [ ] Configuration Vault
- [ ] Module Terraform linux-vm
- [ ] Déploiement première VM lab