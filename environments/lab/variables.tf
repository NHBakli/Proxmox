variable "proxmox_url" {
  description = "URL de l'API Proxmox"
  type        = string
  default     = "https://192.168.139.128:8006/api2/json"  # Ton IP Proxmox
}

variable "proxmox_username" {
  description = "Utilisateur Proxmox"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Mot de passe Proxmox"
  type        = string
  sensitive   = true    # Terraform ne l'affichera jamais dans les logs
}

variable "proxmox_ip" {
  description = "IP brute de Proxmox pour la connexion SSH"
  type        = string
  default     = "192.168.139.128"
}

variable "ssh_public_key" {
  description = "Ta clé SSH publique pour accéder aux VMs créées"
  type        = string
  sensitive   = true
}