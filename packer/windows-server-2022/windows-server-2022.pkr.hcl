# Windows Server 2022 Packer Template pour Proxmox VE
# Crée un template Windows Server 2022 sur Proxmox

packer {
  required_version = ">= 1.8.0"
  required_plugins {
    proxmox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ============================================================================
# Source: Proxmox VE
# ============================================================================
source "proxmox-iso" "windows-server-2022" {
  # Connexion Proxmox
  proxmox_url              = "https://${var.proxmox_host}:8006/api2/json"
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_skip_tls_verify
  node                     = var.proxmox_node

  # Configuration VM
  vm_id                = var.vm_id
  vm_name              = var.vm_name
  template_description = "Windows Server 2022 - Template créé par Packer"

  # OS
  os       = "win11"
  bios     = "ovmf"
  machine  = "q35"
  efi_config {
    efi_storage_pool  = var.proxmox_storage
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  # CPU
  cpu_type = "host"
  cores    = var.vm_cpus
  sockets  = 1

  # Mémoire
  memory             = var.vm_memory
  ballooning_minimum = 1024

  # Réseau
  network_adapters {
    bridge   = var.proxmox_network_bridge
    model    = "virtio"
    firewall = false
  }

  # Disque principal
  scsi_controller = "virtio-scsi-single"
  disks {
    type              = "scsi"
    disk_size         = var.vm_disk_size
    storage_pool      = var.proxmox_storage
    format            = "raw"
    io_thread         = true
    discard           = true
    ssd               = true
  }

  # ISO Windows Server 2022
  iso_file = var.iso_file
  # Ou téléchargement automatique :
  # iso_url      = var.iso_url
  # iso_checksum = var.iso_checksum
  # iso_storage_pool = var.proxmox_iso_storage

  # ISO VirtIO drivers (obligatoire pour Windows)
  additional_iso_files {
    device           = "sata1"
    iso_file         = var.virtio_iso_file
    unmount          = true
  }

  # Fichiers Autounattend (via CD-ROM)
  additional_iso_files {
    device   = "sata2"
    cd_files = [
      "${path.root}/http/Autounattend.xml",
      "${path.root}/scripts/winrm-setup.ps1"
    ]
    cd_label = "OEMDRV"
    unmount  = true
  }

  # Communication WinRM
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "6h"
  winrm_insecure = true

  # Boot
  boot_wait = "5s"
  boot_command = ["<spacebar>"]

  # Agent QEMU
  qemu_agent = true

  # Cloud-Init (optionnel)
  cloud_init              = false
  cloud_init_storage_pool = var.proxmox_storage

  # Timeout
  task_timeout = "30m"
}

# ============================================================================
# Build
# ============================================================================
build {
  name = "windows-server-2022"

  sources = ["source.proxmox-iso.windows-server-2022"]

  # Attendre que Windows soit prêt
  provisioner "powershell" {
    inline = [
      "Write-Host 'Attente de Windows...'",
      "Start-Sleep -Seconds 30"
    ]
  }

  # Installation de l'agent QEMU Guest
  provisioner "powershell" {
    script = "${path.root}/scripts/install-qemu-agent.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
  }

  # Installation des mises à jour Windows
  provisioner "powershell" {
    script = "${path.root}/scripts/install-windows-updates.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
    timeout           = "4h"
  }

  # Configuration de base Windows
  provisioner "powershell" {
    script = "${path.root}/scripts/configure-windows.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
  }

  # Installation de Chocolatey et outils de base
  provisioner "powershell" {
    script = "${path.root}/scripts/install-chocolatey.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
  }

  # Nettoyage final
  provisioner "powershell" {
    script = "${path.root}/scripts/cleanup.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
  }

  # Sysprep Windows (généralisation)
  provisioner "powershell" {
    inline = [
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /shutdown /quiet"
    ]
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
  }
}
