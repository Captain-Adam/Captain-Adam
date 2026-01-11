# Variables pour Windows Server 2022 Packer Template - Proxmox VE

# ============================================================================
# Variables Proxmox
# ============================================================================
variable "proxmox_host" {
  type        = string
  description = "Adresse IP ou nom DNS du serveur Proxmox"
  default     = ""
}

variable "proxmox_username" {
  type        = string
  description = "Utilisateur Proxmox (format: user@realm)"
  default     = "root@pam"
}

variable "proxmox_password" {
  type        = string
  description = "Mot de passe Proxmox (si pas de token)"
  sensitive   = true
  default     = ""
}

variable "proxmox_token" {
  type        = string
  description = "Token API Proxmox (format: user@realm!tokenid=token-value)"
  sensitive   = true
  default     = ""
}

variable "proxmox_skip_tls_verify" {
  type        = bool
  description = "Ignorer la vérification du certificat TLS"
  default     = true
}

variable "proxmox_node" {
  type        = string
  description = "Nom du nœud Proxmox"
  default     = "pve"
}

variable "proxmox_storage" {
  type        = string
  description = "Pool de stockage Proxmox pour les disques VM"
  default     = "local-lvm"
}

variable "proxmox_iso_storage" {
  type        = string
  description = "Pool de stockage Proxmox pour les ISO"
  default     = "local"
}

variable "proxmox_network_bridge" {
  type        = string
  description = "Bridge réseau Proxmox"
  default     = "vmbr0"
}

variable "proxmox_network_vlan" {
  type        = number
  description = "VLAN tag pour l'interface réseau (0 = pas de VLAN)"
  default     = 0
}

# ============================================================================
# Variables ISO
# ============================================================================
variable "iso_file" {
  type        = string
  description = "Chemin de l'ISO Windows Server 2022 dans Proxmox (ex: local:iso/win2022.iso)"
  default     = "local:iso/SERVER_EVAL_x64FRE_fr-fr.iso"
}

variable "iso_url" {
  type        = string
  description = "URL de téléchargement de l'ISO (alternative à iso_file)"
  default     = ""
}

variable "iso_checksum" {
  type        = string
  description = "Checksum de l'ISO (sha256:...)"
  default     = ""
}

variable "virtio_iso_file" {
  type        = string
  description = "Chemin de l'ISO VirtIO drivers dans Proxmox"
  default     = "local:iso/virtio-win.iso"
}

# ============================================================================
# Variables VM
# ============================================================================
variable "vm_id" {
  type        = number
  description = "ID de la VM dans Proxmox (0 = auto)"
  default     = 0
}

variable "vm_name" {
  type        = string
  description = "Nom de la VM/Template"
  default     = "windows-server-2022-template"
}

variable "vm_cpus" {
  type        = number
  description = "Nombre de vCPUs"
  default     = 4
}

variable "vm_memory" {
  type        = number
  description = "Mémoire RAM en Mo"
  default     = 8192
}

variable "vm_disk_size" {
  type        = string
  description = "Taille du disque (ex: 60G)"
  default     = "60G"
}

# ============================================================================
# Variables WinRM
# ============================================================================
variable "winrm_username" {
  type        = string
  description = "Utilisateur WinRM"
  default     = "Administrator"
}

variable "winrm_password" {
  type        = string
  description = "Mot de passe WinRM"
  sensitive   = true
  default     = "P@ssw0rd123!"
}

# ============================================================================
# Variables Windows
# ============================================================================
variable "windows_edition" {
  type        = string
  description = "Edition Windows Server (SERVERSTANDARDCORE, SERVERSTANDARD, SERVERDATACENTERCORE, SERVERDATACENTER)"
  default     = "SERVERSTANDARD"
}

variable "windows_product_key" {
  type        = string
  description = "Clé de produit Windows Server 2022 (KMS ou Retail)"
  default     = "VDYBN-27WPP-V4HQT-9VMD4-VMK7H"
}

variable "windows_timezone" {
  type        = string
  description = "Fuseau horaire Windows"
  default     = "Romance Standard Time"
}

variable "windows_language" {
  type        = string
  description = "Langue d'installation Windows"
  default     = "fr-FR"
}

# ============================================================================
# Variables d'optimisation
# ============================================================================
variable "skip_windows_updates" {
  type        = bool
  description = "Ignorer l'installation des mises à jour Windows (accélère la création)"
  default     = false
}

variable "skip_chocolatey" {
  type        = bool
  description = "Ignorer l'installation de Chocolatey et des outils"
  default     = false
}

variable "vm_cpus_build" {
  type        = number
  description = "Nombre de vCPUs pendant le build (plus = plus rapide)"
  default     = 0
}

variable "vm_memory_build" {
  type        = number
  description = "Mémoire RAM pendant le build en Mo (plus = plus rapide)"
  default     = 0
}
