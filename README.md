# proxmox-iac

Infrastructure as Code (IaC) pour déployer et gérer des VMs sur Proxmox via Terraform.

> **C'est quoi l'Infrastructure as Code ?**
> Au lieu de créer des VMs à la main dans l'interface web de Proxmox, on écrit des fichiers de configuration. Terraform lit ces fichiers et crée les VMs automatiquement. L'avantage : tout est versionné, reproductible, et documenté dans le code.

---

## Stack technique

| Outil | Rôle |
|---|---|
| **Terraform** | Déploie les VMs à partir des templates |
| **Packer** | *(à venir)* Crée des templates de VMs personnalisés |
| **Vault** | *(à venir)* Stocke les secrets (mots de passe, tokens, clés SSH) |

---

## Prérequis

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- Un serveur Proxmox VE accessible en réseau depuis ton poste

### Installation de Terraform (Ubuntu/Debian)

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform
```

---

## Comprendre les concepts clés

### Le provider Terraform

Terraform ne sait pas nativement parler à Proxmox. Un **provider** est un plugin qui fait le pont entre Terraform et un service cible (Proxmox, AWS, Azure...).

Ce projet utilise **`bpg/proxmox`** — le provider Proxmox le plus activement maintenu à ce jour. Il n'est pas officiel (Proxmox ne fournit pas de provider Terraform), mais c'est la référence de la communauté.

> Il existe aussi `telmate/proxmox`, plus ancien et quasi abandonné. Ne pas l'utiliser pour de nouveaux projets.

### Comment Terraform communique avec Proxmox

Terraform a besoin de **deux chemins** vers ton serveur Proxmox :

```
[Ton poste]
    │
    ├── API REST (HTTPS :8006) ──► Proxmox  ← pour créer/gérer les VMs
    └── SSH (:22) ───────────────► Proxmox  ← pour préparer le template Ubuntu
```

1. **L'API REST** (port 8006) : utilisée par le provider `bpg/proxmox` pour créer, modifier et supprimer les VMs.
2. **SSH** : utilisé par la ressource `null_resource` pour exécuter des commandes directement sur Proxmox (téléchargement de l'image Ubuntu, création du template).

### Le template et le clonage

Pour créer des VMs rapidement, on utilise un **template** (ID 9000) : une VM de base préconfigurée qu'on ne démarre jamais, et qu'on **clone** pour créer de vraies VMs.

```
Template Ubuntu (ID 9000)
    ├── Clone → vm-lab-01 (ID 101)
    ├── Clone → vm-lab-02 (ID 102)  ← facile d'en ajouter d'autres
    └── Clone → vm-lab-03 (ID 103)
```

### Cloud-Init

**Cloud-Init** est un système qui s'exécute au premier démarrage d'une VM Linux. Il lit une configuration (IP, utilisateur, clé SSH) et l'applique automatiquement. C'est grâce à lui qu'on peut déployer une VM avec une IP fixe et un accès SSH sans jamais ouvrir la console Proxmox.

### Les modules Terraform

Un **module** est un dossier de fichiers `.tf` réutilisable. Plutôt que de recopier 50 lignes de config pour chaque VM, on appelle le module `linux-vm` en lui passant des paramètres différents :

```hcl
module "vm_lab_01" {
  source     = "../../modules/linux-vm"
  vm_name    = "vm-lab-01"
  ip_address = "192.168.1.50/24"
  # ...
}

module "vm_lab_02" {
  source     = "../../modules/linux-vm"
  vm_name    = "vm-lab-02"
  ip_address = "192.168.1.51/24"
  # ...
}
```

---

## Structure du projet

```
proxmox-iac/
│
├── modules/
│   └── linux-vm/                  # Module réutilisable pour créer une VM Linux
│       ├── main.tf                # Définit la ressource proxmox_virtual_environment_vm
│       ├── variables.tf           # Paramètres acceptés par le module (CPU, RAM, IP...)
│       ├── outputs.tf             # Valeurs retournées après création (IP, nom, ID)
│       └── versions.tf            # Déclare que ce module a besoin du provider bpg/proxmox
│
├── environments/
│   └── lab/                       # Environnement de test
│       ├── providers.tf           # Configure le provider bpg/proxmox + connexion à Proxmox
│       ├── variables.tf           # Variables de l'environnement (IP, credentials...)
│       └── main.tf                # Création du template Ubuntu + déclaration des VMs
│
├── Makefile                       # Raccourcis de commandes
├── .gitignore                     # Exclut les secrets et fichiers générés
└── README.md
```

---

## Explication détaillée des fichiers

### `environments/lab/providers.tf`

Ce fichier a deux rôles :

1. **Déclarer les providers** dont Terraform a besoin (il les téléchargera lors du `terraform init`)
2. **Configurer la connexion** à Proxmox via l'API REST

```hcl
provider "proxmox" {
  endpoint = var.proxmox_url   # https://192.168.139.128:8006/api2/json
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true              # Accepte le certificat SSL auto-signé de Proxmox
}
```

> `insecure = true` est nécessaire car Proxmox utilise par défaut un certificat SSL auto-signé que Terraform refuse sinon.

---

### `environments/lab/variables.tf`

Déclare toutes les variables de l'environnement. Les valeurs sensibles (mot de passe, clé SSH) sont marquées `sensitive = true` — Terraform ne les affichera jamais dans les logs ou le plan.

| Variable | Rôle | Valeur par défaut |
|---|---|---|
| `proxmox_url` | URL de l'API Proxmox | `https://192.168.139.128:8006/api2/json` |
| `proxmox_username` | Utilisateur Proxmox | `root@pam` |
| `proxmox_password` | Mot de passe | *(obligatoire, via variable d'env)* |
| `proxmox_ip` | IP pour la connexion SSH | `192.168.139.128` |
| `ssh_public_key` | Clé SSH publique pour les VMs | *(obligatoire, via variable d'env)* |

> Les deux IPs (`proxmox_url` et `proxmox_ip`) doivent pointer vers le même serveur Proxmox. L'une est utilisée pour l'API REST, l'autre pour SSH.

---

### `environments/lab/main.tf`

Le fichier principal, découpé en deux parties :

**Partie 1 — Création du template** via `null_resource` :

```
Terraform → SSH → Proxmox
                    ├── wget ubuntu-22.04.img
                    ├── qm create 9000
                    ├── qm importdisk 9000 ...
                    └── qm template 9000
```

Le `triggers` sur `template_id = "9000"` garantit que Terraform ne recrée le template que si cet ID change. Si tu relances `terraform apply`, cette étape est ignorée (le template existe déjà).

**Partie 2 — Création de la VM** via le module `linux-vm` :

```hcl
module "vm_lab_01" {
  source         = "../../modules/linux-vm"
  depends_on     = [null_resource.ubuntu_template]  # Attend que le template soit prêt
  vm_name        = "vm-lab-01"
  vm_id          = 101
  ip_address     = "192.168.1.50/24"
  # ...
}
```

Le `depends_on` est crucial : il force Terraform à créer le template **avant** de tenter de cloner la VM.

---

### `modules/linux-vm/main.tf`

Crée la VM dans Proxmox via le provider `bpg/proxmox`. La ressource s'appelle `proxmox_virtual_environment_vm` (spécifique à ce provider).

Points clés :
- **`clone`** : clone le template ID 9000 en copie complète (`full = true`)
- **`initialization`** : bloc Cloud-Init qui injecte l'IP fixe, l'utilisateur et la clé SSH au premier démarrage
- **`agent`** : active QEMU Guest Agent pour que Proxmox puisse communiquer avec la VM

---

### `modules/linux-vm/variables.tf`

Paramètres acceptés par le module. Chaque VM créée avec ce module peut avoir ses propres valeurs.

| Variable | Type | Description |
|---|---|---|
| `vm_name` | string | Nom affiché dans Proxmox |
| `vm_id` | number | ID unique (101, 102, 103...) |
| `cores` | number | Nombre de cœurs CPU |
| `memory` | number | RAM en Mo (512, 1024, 2048...) |
| `disk_size` | number | Taille du disque en **Go** (8, 20, 50...) |
| `storage` | string | Nom du stockage Proxmox (`local-lvm`) |
| `ip_address` | string | IP fixe avec masque CIDR (`192.168.1.50/24`) |
| `gateway` | string | Passerelle réseau (`192.168.1.1`) |
| `ssh_public_key` | string | Clé publique SSH pour l'accès à la VM |

> `disk_size` est un **nombre entier en Go** (ex: `8` pour 8 Go). Le provider `bpg/proxmox` n'accepte pas le format chaîne `"8G"`.

---

### `modules/linux-vm/outputs.tf`

Définit les valeurs retournées par le module après création. Ces valeurs sont accessibles depuis `environments/lab/main.tf` et affichées en fin de `terraform apply`.

```
Outputs:
  vm_lab_01_ip = "192.168.1.50/24"
```

---

### `modules/linux-vm/versions.tf`

Indique à Terraform que ce module utilise le provider `bpg/proxmox`. Sans ce fichier, Terraform cherche le provider `proxmox` chez HashiCorp (qui n'existe pas) et plante.

---

## Mise en route

### Étape 1 — Vérifier l'accès réseau à Proxmox

```bash
ping 192.168.139.128
```

L'IP doit répondre depuis ton poste.

### Étape 2 — Générer une clé SSH (si tu n'en as pas)

La clé SSH permet de se connecter aux VMs sans mot de passe.

```bash
ssh-keygen -t rsa -b 4096
# Appuie sur Entrée pour accepter les valeurs par défaut
```

### Étape 3 — Exporter les secrets

Les secrets ne sont **jamais écrits dans les fichiers** (risque de les committer sur Git). Ils sont passés via des variables d'environnement que Terraform lit automatiquement grâce au préfixe `TF_VAR_` :

```bash
export TF_VAR_proxmox_password="TON_MOT_DE_PASSE_PROXMOX"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
```

> Ces exports disparaissent à la fermeture du terminal. Tu devras les refaire à chaque nouvelle session.

### Étape 4 — Initialiser Terraform

Télécharge les providers déclarés dans `providers.tf` (à faire une seule fois) :

```bash
make tf-init
```

Terraform crée un dossier `.terraform/` avec les plugins téléchargés et un fichier `.terraform.lock.hcl` qui fixe les versions exactes.

### Étape 5 — Prévisualiser les changements

Vérifie ce que Terraform va créer **sans rien toucher** :

```bash
make tf-plan
```

Terraform affiche la liste de toutes les ressources qu'il va créer/modifier/supprimer. C'est une étape de validation importante — lis toujours le plan avant d'appliquer.

### Étape 6 — Déployer

Crée le template et la VM sur Proxmox :

```bash
make tf-apply
```

Terraform va :
1. Se connecter en SSH à Proxmox
2. Télécharger l'image cloud Ubuntu 22.04 (~600 Mo) directement sur Proxmox
3. Créer et configurer le template (ID 9000)
4. Cloner le template pour créer la VM `vm-lab-01` (ID 101)
5. Injecter l'IP, l'utilisateur et la clé SSH via Cloud-Init
6. Afficher l'IP de la VM à la fin

### Étape 7 — Se connecter à la VM

```bash
ssh ubuntu@192.168.1.50
```

### Étape 8 — Supprimer les VMs

```bash
make tf-destroy
```

> Le template (ID 9000) n'est **pas supprimé** par `terraform destroy` — seules les VMs créées via le module `linux-vm` le sont.

---

## Commandes disponibles (Makefile)

| Commande | Action |
|---|---|
| `make tf-init` | Initialise les providers Terraform |
| `make tf-plan` | Prévisualise les changements sans rien créer |
| `make tf-apply` | Déploie les VMs |
| `make tf-destroy` | Supprime toutes les VMs |
| `make packer-init` | Initialise les plugins Packer *(à venir)* |
| `make packer-validate` | Valide la syntaxe du template Packer *(à venir)* |
| `make packer-build` | Construit le template dans Proxmox *(à venir)* |

---

## Problèmes connus

### KVM non disponible — Proxmox tourne dans VMware

Si tu vois cette erreur lors du `terraform apply` :

```
KVM virtualisation configured, but not available.
Either disable in VM configuration or enable in BIOS.
```

**Cause** : ton Proxmox tourne lui-même dans une VM VMware. Par défaut, VMware n'expose pas les instructions de virtualisation matérielle (Intel VT-x / AMD-V) à ses VMs invitées. Proxmox ne peut donc pas démarrer de VMs avec KVM.

**Solution : activer la virtualisation imbriquée dans VMware**

1. **Éteins** ta VM Proxmox dans VMware
2. **Clique droit** sur la VM → **Modifier les paramètres**
3. Onglet **Processeurs** → coche **"Virtualiser Intel VT-x/EPT ou AMD-V/RVI"**
4. **Redémarre** la VM Proxmox

Puis relance :

```bash
make tf-apply
```

> Le template (ID 9000) ne sera pas recréé — Terraform garde l'état de ce qui a déjà été fait dans son fichier `terraform.tfstate`. Il reprend directement à la création de la VM.

---

## Ce qui est commité sur Git (et ce qui ne l'est pas)

Quand tu travailles avec Terraform, certains fichiers sont générés automatiquement ou contiennent des données sensibles — ils ne doivent **jamais** aller sur Git.

### Ce que le `.gitignore` exclut

| Fichier / Dossier | Pourquoi l'exclure |
|---|---|
| `.terraform/` | Contient les binaires des providers (~50 Mo). Chaque développeur les télécharge lui-même via `terraform init`. Inutile et lourd à committer. |
| `terraform.tfstate` | **Le plus critique.** Contient l'état réel de ton infrastructure : IDs des VMs, IPs, parfois des secrets. Ne doit jamais être public. |
| `terraform.tfstate.backup` | Copie de sauvegarde automatique du state avant chaque apply. Même raison que ci-dessus. |
| `*.tfstate.lock.info` | Verrou temporaire actif pendant un `terraform apply`. Fichier purement temporaire, n'a aucune valeur une fois l'opération terminée. |
| `*.tfvars` | Fichiers de variables avec valeurs réelles — souvent utilisés pour passer des secrets localement. |
| `*.pkrvars.hcl` | Variables Packer (même principe que `.tfvars`). |

### Ce qui EST commité

| Fichier | Pourquoi le committer |
|---|---|
| `*.tf` (tous les fichiers Terraform) | C'est le code — la description de l'infrastructure. C'est exactement ce qui doit être versionné. |
| `.terraform.lock.hcl` | Fixe les versions exactes des providers. Garantit que tout le monde utilise les mêmes versions. **Doit être commité sur Git.** |
| `Makefile`, `README.md` | Documentation et raccourcis utiles à toute l'équipe. |

> **Règle d'or** : si un fichier contient une valeur concrète (un mot de passe, une IP sensible, un token), il ne doit pas être sur Git. Si un fichier décrit une *structure* (des types, des noms de variables, de la logique), il peut l'être.

### Focus sur `.terraform.lock.hcl`

Ce fichier mérite une attention particulière car son rôle est souvent mal compris.

Quand tu déclares un provider dans `providers.tf`, tu indiques une contrainte de version :

```hcl
proxmox = {
  source  = "bpg/proxmox"
  version = "~> 0.66.0"   # signifie : 0.66.x, mais pas 0.67
}
```

Cette contrainte est large — `0.66.0`, `0.66.3`, `0.66.9` sont toutes valides. Le `.terraform.lock.hcl` va plus loin : il **fige la version exacte** qui a été réellement téléchargée, ainsi que son empreinte cryptographique :

```hcl
provider "registry.terraform.io/bpg/proxmox" {
  version     = "0.66.3"        ← version exacte utilisée
  constraints = "~> 0.66.0"
  hashes = [
    "h1:xxx...",                 ← empreinte du binaire pour vérifier l'intégrité
  ]
}
```

**Sans ce fichier sur Git** :
- Toi aujourd'hui → `bpg/proxmox 0.66.3`
- Ton collègue demain → `bpg/proxmox 0.66.9` (nouvelle version sortie entre-temps)
- Résultat : comportements différents, bugs difficiles à reproduire

**Avec ce fichier sur Git** : tout le monde télécharge exactement la même version. C'est le même principe que `package-lock.json` en Node.js ou `Pipfile.lock` en Python.

---

## Sécurité

- Les credentials sont passés uniquement via variables d'environnement (`TF_VAR_*`) — jamais écrits dans les fichiers
- `insecure = true` dans le provider est acceptable en lab, à remplacer par un vrai certificat en production
- Vault sera ajouté ultérieurement pour centraliser la gestion des secrets

---

## Avancement

- [x] Structure du projet
- [x] Installation des outils (Terraform)
- [x] Makefile
- [x] Module Terraform `linux-vm`
- [x] Création du template Ubuntu via `null_resource` + SSH
- [x] Connexion API Proxmox validée (`terraform plan` OK)
- [x] Déploiement de la première VM lab (`terraform apply`)
- [ ] Intégration Vault pour la gestion des secrets
- [ ] Templates Packer avancés
