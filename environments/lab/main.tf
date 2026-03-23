resource "null_resource" "ubuntu_template" {

  triggers = {
    template_id = "9000"    # Terraform ne relance ce bloc que si cet ID change
  }

  # Comment se connecter à Proxmox en SSH
  connection {
    type     = "ssh"
    host     = var.proxmox_ip
    user     = "root"
    password = var.proxmox_password
  }

  # Les commandes à exécuter sur Proxmox
  provisioner "remote-exec" {
    inline = [
      # Si la VM 9000 existe déjà, on sort sans rien faire
      "if qm status 9000 > /dev/null 2>&1; then echo 'Template existe deja'; exit 0; fi",

      # Télécharge l'image cloud Ubuntu (600 Mo, directement sur Proxmox)
      "wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /tmp/ubuntu-22.img",

      # Crée une VM vide avec l'ID 9000
      "qm create 9000 --name ubuntu-22-cloud --memory 512 --cores 1 --net0 virtio,bridge=vmbr0 --ostype l26",

      # Attache le disque téléchargé à la VM
      "qm importdisk 9000 /tmp/ubuntu-22.img local-lvm",

      # Configure le disque principal
      "qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0,discard=on",

      # Ajoute le lecteur Cloud-Init (injecte IP/user/SSH au démarrage)
      "qm set 9000 --ide2 local-lvm:cloudinit",

      # Démarre sur le bon disque
      "qm set 9000 --boot order=scsi0",

      # Nécessaire pour Cloud-Init
      "qm set 9000 --serial0 socket --vga serial0",

      # Active la communication entre Proxmox et la VM
      "qm set 9000 --agent enabled=1",

      # Transforme la VM en template (ne peut plus démarrer directement)
      "qm template 9000",

      # Supprime l'image téléchargée, plus besoin
      "rm -f /tmp/ubuntu-22.img",

      "echo 'Template pret !'"
    ]
  }
}

module "vm_lab_01" {
  source = "../../modules/linux-vm"

  depends_on = [null_resource.ubuntu_template]  # Attend que le template soit créé

  vm_name        = "vm-lab-01"
  vm_id          = 101
  clone_template = "ubuntu-22-cloud"   # Le nom du template créé juste au-dessus
  cores          = 1
  memory         = 512
  disk_size      = 8
  storage        = "local-lvm"
  ip_address     = "192.168.1.50/24"   # IP fixe de la VM
  gateway        = "192.168.1.1"
  ssh_public_key = var.ssh_public_key
}

# Affiche l'IP dans le terminal à la fin du terraform apply
output "vm_lab_01_ip" {
  value = module.vm_lab_01.vm_ip
}