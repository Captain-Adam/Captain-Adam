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
# Variables locales pour l'optimisation
# ============================================================================
locals {
  # Utiliser plus de ressources pendant le build si spécifié
  build_cpus   = var.vm_cpus_build > 0 ? var.vm_cpus_build : var.vm_cpus
  build_memory = var.vm_memory_build > 0 ? var.vm_memory_build : var.vm_memory
}

# ============================================================================
# Source: Proxmox VE
# ============================================================================
source "proxmox-iso" "windows-server-2022" {
  # Connexion Proxmox
  proxmox_url              = "https://${var.proxmox_host}:8006/api2/json"
  username                 = var.proxmox_username
  password                 = var.proxmox_password != "" ? var.proxmox_password : null
  token                    = var.proxmox_token != "" ? var.proxmox_token : null
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

  # CPU - Utiliser plus de cores pendant le build pour accélérer
  cpu_type = "host"
  cores    = local.build_cpus
  sockets  = 1

  # Mémoire - Utiliser plus de RAM pendant le build
  memory             = local.build_memory
  ballooning_minimum = 0

  # Réseau
  network_adapters {
    bridge   = var.proxmox_network_bridge
    model    = "virtio"
    firewall = false
    vlan_tag = var.proxmox_network_vlan > 0 ? var.proxmox_network_vlan : null
  }

  # Disque principal - Optimisé pour la vitesse
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    disk_size    = var.vm_disk_size
    storage_pool = var.proxmox_storage
    format       = "raw"
    io_thread    = true
    discard      = true
    ssd          = true
  }

  # ISO Windows Server 2022
  iso_file = var.iso_file

  # ISO VirtIO drivers (obligatoire pour Windows)
  additional_iso_files {
    device   = "sata1"
    iso_file = var.virtio_iso_file
    unmount  = true
  }

  # Fichiers Autounattend (via CD-ROM)
  additional_iso_files {
    device           = "sata2"
    iso_storage_pool = var.proxmox_iso_storage
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
  winrm_timeout  = "2h"
  winrm_insecure = true

  # Boot
  boot_wait    = "3s"
  boot_command = ["<spacebar>"]

  # Agent QEMU
  qemu_agent = true

  # Cloud-Init (optionnel)
  cloud_init              = false
  cloud_init_storage_pool = var.proxmox_storage

  # Timeout
  task_timeout = "20m"
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
      "Write-Host 'Windows est prêt, démarrage du provisionnement...'"
    ]
  }

  # Installation de l'agent QEMU Guest
  provisioner "powershell" {
    script            = "${path.root}/scripts/install-qemu-agent.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
  }

  # Installation des mises à jour Windows (optionnel)
  provisioner "powershell" {
    script            = "${path.root}/scripts/install-windows-updates.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
    timeout           = "3h"
    only              = var.skip_windows_updates ? [] : ["proxmox-iso.windows-server-2022"]
  }

  # Configuration de base Windows
  provisioner "powershell" {
    script            = "${path.root}/scripts/configure-windows.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
  }

  # Installation de Chocolatey et outils de base (optionnel)
  provisioner "powershell" {
    script            = "${path.root}/scripts/install-chocolatey.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
    only              = var.skip_chocolatey ? [] : ["proxmox-iso.windows-server-2022"]
  }

  # Nettoyage final
  provisioner "powershell" {
    script            = "${path.root}/scripts/cleanup.ps1"
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
