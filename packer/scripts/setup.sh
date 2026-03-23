#!/bin/bash
set -e  # Arrête le script si une commande échoue

echo "🔄 Mise à jour du système..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "📦 Installation des paquets essentiels..."
sudo apt-get install -y \
  curl \
  wget \
  git \
  htop \
  vim \
  unzip \
  net-tools \
  qemu-guest-agent \
  cloud-init \
  cloud-utils \
  cloud-initramfs-growroot  # Permet au disque de s'agrandir automatiquement

echo "⚙️ Activation du guest agent Proxmox..."
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent

echo "🧹 Nettoyage des paquets inutiles..."
sudo apt-get autoremove -y
sudo apt-get autoclean -y

echo "✅ Setup terminé !"