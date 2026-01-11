# Variables pour Windows Server 2022 Packer Template

# ============================================================================
# Variables vSphere
# ============================================================================
variable "vsphere_server" {
  type        = string
  description = "Adresse du serveur vCenter"
  default     = ""
}

variable "vsphere_user" {
  type        = string
  description = "Utilisateur vCenter"
  default     = ""
}

variable "vsphere_password" {
  type        = string
  description = "Mot de passe vCenter"
  sensitive   = true
  default     = ""
}

variable "vsphere_insecure" {
  type        = bool
  description = "Ignorer la vérification SSL"
  default     = true
}

variable "vsphere_datacenter" {
  type        = string
  description = "Datacenter vSphere"
  default     = ""
}

variable "vsphere_cluster" {
  type        = string
  description = "Cluster vSphere"
  default     = ""
}

variable "vsphere_datastore" {
  type        = string
  description = "Datastore vSphere"
  default     = ""
}

variable "vsphere_folder" {
  type        = string
  description = "Dossier VM dans vSphere"
  default     = "Templates"
}

variable "vsphere_network" {
  type        = string
  description = "Réseau vSphere"
  default     = "VM Network"
}

# ============================================================================
# Variables Hyper-V
# ============================================================================
variable "hyperv_switch_name" {
  type        = string
  description = "Nom du switch Hyper-V"
  default     = "Default Switch"
}

# ============================================================================
# Variables ISO
# ============================================================================
variable "iso_path" {
  type        = string
  description = "Chemin de l'ISO Windows Server 2022 (pour vSphere)"
  default     = "[datastore1] ISO/Windows_Server_2022.iso"
}

variable "iso_url" {
  type        = string
  description = "URL de l'ISO Windows Server 2022"
  default     = ""
}

variable "iso_checksum" {
  type        = string
  description = "Checksum de l'ISO (sha256:...)"
  default     = ""
}

# ============================================================================
# Variables VM
# ============================================================================
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

variable "vm_cpu_cores" {
  type        = number
  description = "Nombre de cores par CPU"
  default     = 1
}

variable "vm_memory" {
  type        = number
  description = "Mémoire RAM en Mo"
  default     = 8192
}

variable "vm_disk_size" {
  type        = number
  description = "Taille du disque en Mo"
  default     = 61440
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
  default     = "VDYBN-27WPP-V4HQT-9VMD4-VMK7H"  # KMS Key pour Standard
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

variable "windows_keyboard" {
  type        = string
  description = "Disposition du clavier"
  default     = "040c:0000040c"
}
