# Script de configuration WinRM pour Packer
# Ce script configure WinRM pour permettre la communication avec Packer

# Ne pas arrêter sur les erreurs pour s'assurer que tout s'exécute
$ErrorActionPreference = "Continue"

Write-Host "=== Configuration de WinRM pour Packer ===" -ForegroundColor Green

# Attendre que le réseau soit disponible
Write-Host "Attente de la connectivité réseau..."
Start-Sleep -Seconds 10

# Définir le profil réseau comme Privé
Write-Host "Configuration du profil réseau..."
try {
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
} catch {
    Write-Host "Impossible de changer le profil réseau: $_"
}

# Désactiver complètement le pare-feu
Write-Host "Désactivation du pare-feu..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Configurer WinRM de manière simple et directe
Write-Host "Configuration de WinRM..."

# Arrêter le service WinRM s'il est en cours d'exécution
Stop-Service WinRM -Force -ErrorAction SilentlyContinue

# Configuration du service WinRM
Set-Service -Name WinRM -StartupType Automatic

# Démarrer le service
Start-Service WinRM

# Configuration basique via winrm
cmd /c 'winrm quickconfig -q -force'
cmd /c 'winrm set winrm/config @{MaxTimeoutms="1800000"}'
cmd /c 'winrm set winrm/config/service @{AllowUnencrypted="true"}'
cmd /c 'winrm set winrm/config/service/auth @{Basic="true"}'
cmd /c 'winrm set winrm/config/client @{AllowUnencrypted="true"}'
cmd /c 'winrm set winrm/config/client/auth @{Basic="true"}'
cmd /c 'winrm set winrm/config/winrs @{MaxMemoryPerShellMB="2048"}'

# S'assurer que le listener HTTP existe
cmd /c 'winrm delete winrm/config/Listener?Address=*+Transport=HTTP' 2>$null
cmd /c 'winrm create winrm/config/Listener?Address=*+Transport=HTTP'

# Redémarrer le service WinRM
Restart-Service WinRM

# Configurer PowerShell Remoting
Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction SilentlyContinue

# Ajouter règle de pare-feu explicite pour WinRM (au cas où)
netsh advfirewall firewall add rule name="WinRM HTTP" dir=in action=allow protocol=TCP localport=5985

# Afficher la configuration
Write-Host ""
Write-Host "=== Configuration WinRM terminée ===" -ForegroundColor Green
Write-Host "IP de la machine:"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object IPAddress

Write-Host ""
Write-Host "Service WinRM:"
Get-Service WinRM | Select-Object Status, StartType

Write-Host ""
Write-Host "Test WinRM:"
Test-WSMan -ErrorAction SilentlyContinue
