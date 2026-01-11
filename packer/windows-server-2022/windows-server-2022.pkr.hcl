# Windows Server 2022 Packer Template
# Compatible avec VMware vSphere, Hyper-V, et VirtualBox

packer {
  required_version = ">= 1.8.0"
  required_plugins {
    vsphere = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/vsphere"
    }
    hyperv = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/hyperv"
    }
    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

# ============================================================================
# Source: VMware vSphere
# ============================================================================
source "vsphere-iso" "windows-server-2022" {
  # Connexion vCenter
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  insecure_connection = var.vsphere_insecure

  # Emplacement VM
  datacenter = var.vsphere_datacenter
  cluster    = var.vsphere_cluster
  datastore  = var.vsphere_datastore
  folder     = var.vsphere_folder

  # Configuration VM
  vm_name              = var.vm_name
  guest_os_type        = "windows2019srvNext_64Guest"
  firmware             = "efi"
  CPUs                 = var.vm_cpus
  cpu_cores            = var.vm_cpu_cores
  RAM                  = var.vm_memory
  RAM_reserve_all      = false
  disk_controller_type = ["pvscsi"]

  storage {
    disk_size             = var.vm_disk_size
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  # ISO
  iso_paths = [var.iso_path]

  # Floppy pour Autounattend
  floppy_files = [
    "${path.root}/http/Autounattend.xml",
    "${path.root}/scripts/winrm-setup.ps1"
  ]

  # Communication
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "6h"

  # Boot
  boot_order = "disk,cdrom"
  boot_wait  = "5s"
  boot_command = ["<spacebar>"]

  # Conversion en template
  convert_to_template = true
}

# ============================================================================
# Source: Hyper-V
# ============================================================================
source "hyperv-iso" "windows-server-2022" {
  # Configuration VM
  vm_name          = var.vm_name
  generation       = 2
  cpus             = var.vm_cpus
  memory           = var.vm_memory
  disk_size        = var.vm_disk_size
  enable_secure_boot = true
  secure_boot_template = "MicrosoftWindows"

  # ISO
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Floppy pour Autounattend
  secondary_iso_images = []
  cd_files = [
    "${path.root}/http/Autounattend.xml",
    "${path.root}/scripts/winrm-setup.ps1"
  ]

  # Réseau
  switch_name = var.hyperv_switch_name

  # Communication
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "6h"

  # Boot
  boot_wait = "5s"
  boot_command = ["<spacebar>"]

  # Output
  output_directory = "${path.root}/output/hyperv-${var.vm_name}"

  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
}

# ============================================================================
# Source: VirtualBox
# ============================================================================
source "virtualbox-iso" "windows-server-2022" {
  # Configuration VM
  vm_name    = var.vm_name
  guest_os_type = "Windows2019_64"
  cpus       = var.vm_cpus
  memory     = var.vm_memory
  disk_size  = var.vm_disk_size
  firmware   = "efi"

  # ISO
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Floppy pour Autounattend
  floppy_files = [
    "${path.root}/http/Autounattend.xml",
    "${path.root}/scripts/winrm-setup.ps1"
  ]

  # Guest Additions
  guest_additions_mode = "upload"
  guest_additions_path = "C:/Windows/Temp/VBoxGuestAdditions.iso"

  # Communication
  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_timeout  = "6h"

  # Boot
  boot_wait = "5s"
  boot_command = ["<spacebar>"]

  # Output
  output_directory = "${path.root}/output/virtualbox-${var.vm_name}"

  shutdown_command = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
}

# ============================================================================
# Build
# ============================================================================
build {
  name = "windows-server-2022"

  sources = [
    "source.vsphere-iso.windows-server-2022",
    "source.hyperv-iso.windows-server-2022",
    "source.virtualbox-iso.windows-server-2022"
  ]

  # Attendre que Windows soit prêt
  provisioner "powershell" {
    inline = [
      "Write-Host 'Attente de Windows...'",
      "Start-Sleep -Seconds 30"
    ]
  }

  # Installation des mises à jour Windows
  provisioner "powershell" {
    script = "${path.root}/scripts/install-windows-updates.ps1"
    elevated_user     = var.winrm_username
    elevated_password = var.winrm_password
    timeout           = "4h"
  }

  # Installation des outils VMware (uniquement pour vSphere)
  provisioner "powershell" {
    only   = ["vsphere-iso.windows-server-2022"]
    script = "${path.root}/scripts/install-vmware-tools.ps1"
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
