# Packer Windows Server 2022 pour Proxmox VE

Ce projet Packer permet de créer automatiquement des templates Windows Server 2022 sur Proxmox VE.

## Prérequis

- [Packer](https://www.packer.io/) >= 1.8.0
- Proxmox VE >= 7.0
- ISO Windows Server 2022 (Evaluation ou Retail)
- ISO VirtIO drivers pour Windows

### Téléchargement des ISO

1. **Windows Server 2022** : [Microsoft Evaluation Center](https://www.microsoft.com/fr-fr/evalcenter/evaluate-windows-server-2022)

2. **VirtIO Drivers** : [Fedora VirtIO-Win](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)

Uploadez les deux ISO sur votre serveur Proxmox via l'interface web (Datacenter > Storage > local > ISO Images > Upload).

## Structure du projet

```
windows-server-2022/
├── windows-server-2022.pkr.hcl              # Template Packer principal
├── variables.pkr.hcl                         # Définition des variables
├── windows-server-2022.auto.pkrvars.hcl.example  # Exemple de configuration
├── http/
│   └── Autounattend.xml                      # Fichier d'installation automatique
├── scripts/
│   ├── winrm-setup.ps1                       # Configuration WinRM
│   ├── configure-windows.ps1                 # Configuration de base Windows
│   ├── install-windows-updates.ps1           # Installation des mises à jour
│   ├── install-qemu-agent.ps1                # Installation QEMU Guest Agent
│   ├── install-chocolatey.ps1                # Installation Chocolatey et outils
│   └── cleanup.ps1                           # Nettoyage final
└── output/                                   # Dossier de sortie des images
```

## Configuration

1. Copiez le fichier d'exemple de variables :

```bash
cp windows-server-2022.auto.pkrvars.hcl.example windows-server-2022.auto.pkrvars.hcl
```

2. Modifiez les variables selon votre environnement :

```hcl
# Configuration Proxmox
proxmox_host           = "192.168.1.100"
proxmox_username       = "root@pam"
proxmox_password       = "VotreMotDePasse!"
proxmox_node           = "pve"
proxmox_storage        = "local-lvm"
proxmox_network_bridge = "vmbr0"

# Configuration ISO
iso_file        = "local:iso/SERVER_EVAL_x64FRE_fr-fr.iso"
virtio_iso_file = "local:iso/virtio-win.iso"

# Configuration VM
vm_id        = 9000
vm_name      = "windows-server-2022-template"
vm_cpus      = 4
vm_memory    = 8192
vm_disk_size = "60G"

# Credentials
winrm_username = "Administrator"
winrm_password = "P@ssw0rd123!"
```

### Authentification par Token API (recommandé)

Pour une meilleure sécurité, utilisez un token API Proxmox :

1. Créez un utilisateur et un token dans Proxmox :
```bash
pveum user add packer@pve
pveum aclmod / -user packer@pve -role PVEVMAdmin
pveum user token add packer@pve packer-token --privsep=0
```

2. Utilisez le token dans votre configuration :
```hcl
proxmox_username = "packer@pve"
proxmox_token    = "packer@pve!packer-token=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
proxmox_password = ""  # Laisser vide si vous utilisez un token
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

### Construction du template

```bash
packer build .
```

### Construction avec variables en ligne de commande

```bash
packer build -var "proxmox_host=192.168.1.100" -var "proxmox_password=secret" .
```

## Personnalisation

### Éditions Windows Server 2022

Modifiez la variable `windows_edition` et le fichier `Autounattend.xml` selon l'édition souhaitée :

| Édition | Valeur | Clé KMS |
|---------|--------|---------|
| Standard (Desktop Experience) | `SERVERSTANDARD` | `VDYBN-27WPP-V4HQT-9VMD4-VMK7H` |
| Standard (Core) | `SERVERSTANDARDCORE` | `VDYBN-27WPP-V4HQT-9VMD4-VMK7H` |
| Datacenter (Desktop Experience) | `SERVERDATACENTER` | `WX4NM-KYWYW-QJJR4-XV3QB-6VM33` |
| Datacenter (Core) | `SERVERDATACENTERCORE` | `WX4NM-KYWYW-QJJR4-XV3QB-6VM33` |

### Scripts de provisionnement

Les scripts PowerShell dans le dossier `scripts/` peuvent être modifiés selon vos besoins :

- **winrm-setup.ps1** : Configure WinRM pour la communication avec Packer
- **configure-windows.ps1** : Configuration de base du système
- **install-windows-updates.ps1** : Installe les mises à jour Windows
- **install-qemu-agent.ps1** : Installe l'agent QEMU et les drivers VirtIO
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

## Fonctionnalités

- **UEFI Boot** : Support du boot UEFI avec OVMF
- **VirtIO** : Drivers VirtIO pour de meilleures performances
- **QEMU Guest Agent** : Communication optimisée avec Proxmox
- **Machine Q35** : Chipset moderne pour Windows
- **Sysprep** : Généralisation automatique du template
- **Mises à jour Windows** : Installation automatique des mises à jour
- **Chocolatey** : Gestionnaire de packages Windows pré-installé

## Dépannage

### WinRM ne se connecte pas

- Vérifiez que le pare-feu Proxmox autorise la communication
- Assurez-vous que le script `winrm-setup.ps1` s'exécute correctement
- Augmentez le timeout WinRM si nécessaire
- Vérifiez les logs dans l'interface Proxmox

### Erreur "No image found"

- Vérifiez que l'édition Windows dans `Autounattend.xml` correspond à l'ISO
- Modifiez la ligne `<Value>Windows Server 2022 SERVERSTANDARD</Value>`

### Drivers VirtIO non trouvés

- Vérifiez que l'ISO VirtIO est bien monté (lecteur E:)
- Vérifiez les chemins dans `Autounattend.xml` (section `DriverPaths`)

### Timeout pendant l'installation

- Augmentez les timeouts dans le fichier principal
- Vérifiez les ressources de la VM (CPU, RAM)
- Vérifiez que l'ISO Windows n'est pas corrompu

### QEMU Guest Agent non installé

- Vérifiez que l'ISO VirtIO est accessible depuis Windows
- Lancez manuellement l'installation depuis `E:\guest-agent\qemu-ga-x86_64.msi`

## Utilisation du template

Une fois le template créé, vous pouvez cloner des VMs depuis Proxmox :

```bash
# Via CLI
qm clone 9000 100 --name "windows-srv-01" --full

# Ou via l'interface web Proxmox
```

## Licence

Ce projet est fourni tel quel, sans garantie d'aucune sorte.
