# Packer Windows Server 2022

Ce projet Packer permet de créer automatiquement des templates/images Windows Server 2022 pour différentes plateformes de virtualisation.

## Plateformes supportées

- **VMware vSphere** - Création de templates vCenter
- **Microsoft Hyper-V** - Création d'images Hyper-V
- **Oracle VirtualBox** - Création d'images VirtualBox

## Prérequis

- [Packer](https://www.packer.io/) >= 1.8.0
- ISO Windows Server 2022 (Evaluation ou Retail)
- Accès à l'infrastructure de virtualisation cible

## Structure du projet

```
windows-server-2022/
├── windows-server-2022.pkr.hcl          # Template Packer principal
├── variables.pkr.hcl                     # Définition des variables
├── windows-server-2022.auto.pkrvars.hcl.example  # Exemple de configuration
├── http/
│   └── Autounattend.xml                  # Fichier d'installation automatique
├── scripts/
│   ├── winrm-setup.ps1                   # Configuration WinRM
│   ├── configure-windows.ps1             # Configuration de base Windows
│   ├── install-windows-updates.ps1       # Installation des mises à jour
│   ├── install-vmware-tools.ps1          # Installation VMware Tools
│   ├── install-chocolatey.ps1            # Installation Chocolatey et outils
│   └── cleanup.ps1                       # Nettoyage final
└── output/                               # Dossier de sortie des images
```

## Configuration

1. Copiez le fichier d'exemple de variables :

```bash
cp windows-server-2022.auto.pkrvars.hcl.example windows-server-2022.auto.pkrvars.hcl
```

2. Modifiez les variables selon votre environnement :

```hcl
# Configuration vSphere
vsphere_server     = "vcenter.example.com"
vsphere_user       = "administrator@vsphere.local"
vsphere_password   = "VotreMotDePasse!"
vsphere_datacenter = "Datacenter"
vsphere_cluster    = "Cluster"
vsphere_datastore  = "Datastore1"

# Configuration VM
vm_name      = "windows-server-2022-template"
vm_cpus      = 4
vm_memory    = 8192
vm_disk_size = 61440

# Credentials
winrm_username = "Administrator"
winrm_password = "P@ssw0rd123!"
```

## Utilisation

### Initialisation des plugins

```bash
packer init windows-server-2022.pkr.hcl
```

### Validation de la configuration

```bash
packer validate .
```

### Construction pour vSphere

```bash
packer build -only="vsphere-iso.windows-server-2022" .
```

### Construction pour Hyper-V

```bash
packer build -only="hyperv-iso.windows-server-2022" .
```

### Construction pour VirtualBox

```bash
packer build -only="virtualbox-iso.windows-server-2022" .
```

### Construction pour toutes les plateformes

```bash
packer build .
```

## Personnalisation

### Éditions Windows Server 2022

Modifiez la variable `windows_edition` selon l'édition souhaitée :

| Édition | Valeur |
|---------|--------|
| Standard (Desktop Experience) | `SERVERSTANDARD` |
| Standard (Core) | `SERVERSTANDARDCORE` |
| Datacenter (Desktop Experience) | `SERVERDATACENTER` |
| Datacenter (Core) | `SERVERDATACENTERCORE` |

### Clés de produit KMS

| Édition | Clé KMS |
|---------|---------|
| Standard | `VDYBN-27WPP-V4HQT-9VMD4-VMK7H` |
| Datacenter | `WX4NM-KYWYW-QJJR4-XV3QB-6VM33` |

### Scripts de provisionnement

Les scripts PowerShell dans le dossier `scripts/` peuvent être modifiés selon vos besoins :

- **winrm-setup.ps1** : Configure WinRM pour la communication avec Packer
- **configure-windows.ps1** : Configuration de base du système
- **install-windows-updates.ps1** : Installe les mises à jour Windows
- **install-vmware-tools.ps1** : Installe les VMware Tools (vSphere uniquement)
- **install-chocolatey.ps1** : Installe Chocolatey et des outils de base
- **cleanup.ps1** : Nettoie le système avant Sysprep

### Ajouter des logiciels

Modifiez le fichier `scripts/install-chocolatey.ps1` pour ajouter des packages :

```powershell
$packages = @(
    "7zip",
    "notepadplusplus",
    "git",
    "vscode",
    "python"
)
```

## Dépannage

### WinRM ne se connecte pas

- Vérifiez que le pare-feu autorise le port 5985 (HTTP) ou 5986 (HTTPS)
- Assurez-vous que le script `winrm-setup.ps1` s'exécute correctement
- Augmentez le timeout WinRM si nécessaire

### Erreur "No image found"

- Vérifiez que l'édition Windows dans `Autounattend.xml` correspond à l'ISO
- Modifiez la ligne `<Value>Windows Server 2022 SERVERSTANDARD</Value>`

### Timeout pendant l'installation

- Augmentez les timeouts dans le fichier principal
- Vérifiez les ressources de la VM (CPU, RAM)

## Licence

Ce projet est fourni tel quel, sans garantie d'aucune sorte.
