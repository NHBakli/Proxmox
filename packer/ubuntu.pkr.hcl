packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_url" {
  type = string
}

variable "proxmox_username" {
  type = string
}

variable "proxmox_password" {
  type = string
}

variable "proxmox_node" {
  type    = string
  default = "pve"
}

source "proxmox-clone" "ubuntu" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id   = 9000
  vm_name = "ubuntu-22-cloud"

  # On part d'une image cloud déjà existante sur Proxmox
  # (on va la télécharger dans Proxmox directement, pas sur ta machine)
  clone_vm = "ubuntu-22-base"

  cores   = 1
  memory  = 512        # Léger pendant la construction

  disks {
    disk_size    = "8G"   # Minimum raisonnable pour Ubuntu
    storage_pool = "local-lvm"
    type         = "scsi"
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  ssh_username         = "ubuntu"
  ssh_private_key_file = "~/.ssh/id_rsa"
  ssh_timeout          = "10m"
}

build {
  sources = ["source.proxmox-clone.ubuntu"]

  provisioner "shell" {
    script = "scripts/setup.sh"
  }

  provisioner "shell" {
    inline = [
      "sudo cloud-init clean",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id"
    ]
  }
}