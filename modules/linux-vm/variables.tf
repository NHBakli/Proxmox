variable "vm_name" {
  description = "Nom de la VM affiché dans Proxmox"
  type        = string
}

variable "vm_id" {
  description = "ID unique dans Proxmox (commence à 101, les <100 sont réservés)"
  type        = number
}

variable "target_node" {
  description = "Nom du nœud Proxmox (visible dans l'interface web)"
  type        = string
  default     = "pve"
}

variable "clone_template" {
  description = "Nom exact du template à cloner"
  type        = string
  default     = "ubuntu-22-cloud"
}

variable "cores" {
  description = "Nombre de cœurs CPU"
  type        = number
  default     = 1
}

variable "memory" {
  description = "RAM en Mo (512 = 512 Mo, 2048 = 2 Go)"
  type        = number
  default     = 512
}

variable "disk_size" {
  description = "Taille du disque en Go (ex: 8, 20)"
  type        = number
  default     = 8
}

variable "storage" {
  description = "Nom du stockage dans Proxmox"
  type        = string
  default     = "local-lvm"
}

variable "ip_address" {
  description = "IP fixe avec masque CIDR (ex: '192.168.1.50/24')"
  type        = string
}

variable "gateway" {
  description = "Passerelle du réseau (ex: '192.168.1.1')"
  type        = string
}

variable "vm_user" {
  description = "Nom de l'utilisateur créé dans la VM par Cloud-Init"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key" {
  description = "Clé SSH publique pour se connecter à la VM sans mot de passe"
  type        = string
  sensitive   = true
}