# Script de configuration WinRM pour Packer
# Ce script configure WinRM pour permettre la communication avec Packer

$ErrorActionPreference = "Stop"

Write-Host "=== Configuration de WinRM pour Packer ===" -ForegroundColor Green

# Attendre que le réseau soit disponible
Write-Host "Attente de la connectivité réseau..."
$maxAttempts = 30
$attempt = 0
while ($attempt -lt $maxAttempts) {
    $networkProfile = Get-NetConnectionProfile -ErrorAction SilentlyContinue
    if ($networkProfile) {
        Write-Host "Réseau connecté: $($networkProfile.Name)"
        break
    }
    Start-Sleep -Seconds 2
    $attempt++
}

# Définir le profil réseau comme Privé (requis pour WinRM)
Write-Host "Configuration du profil réseau en Privé..."
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue

# Activer la découverte réseau
Write-Host "Activation de la découverte réseau..."
netsh advfirewall firewall set rule group="Découverte du réseau" new enable=Yes 2>$null
netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes 2>$null

# Désactiver le pare-feu temporairement pour la configuration
Write-Host "Désactivation temporaire du pare-feu..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Configuration PowerShell Remoting
Write-Host "Configuration de PowerShell Remoting..."
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configuration WinRM
Write-Host "Configuration de WinRM..."
winrm quickconfig -q
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client '@{AllowUnencrypted="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'

# Augmenter les limites WinRM
Write-Host "Configuration des limites WinRM..."
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'
winrm set winrm/config/winrs '@{MaxProcessesPerShell="100"}'
winrm set winrm/config/winrs '@{MaxShellsPerUser="30"}'

# Configuration du listener HTTPS (optionnel)
Write-Host "Configuration du listener WinRM..."
$selector_set = @{
    Address = "*"
    Transport = "HTTP"
}

$value_set = @{
    Enabled = "true"
}

# Créer un listener HTTP si nécessaire
$listeners = winrm enumerate winrm/config/Listener
if ($listeners -notmatch "Transport = HTTP") {
    winrm create winrm/config/Listener?Address=*+Transport=HTTP
}

# Configurer le service WinRM pour démarrer automatiquement
Write-Host "Configuration du service WinRM..."
Set-Service -Name WinRM -StartupType Automatic
Restart-Service WinRM

# Ajouter des règles de pare-feu pour WinRM
Write-Host "Configuration des règles de pare-feu pour WinRM..."
netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow

# Réactiver le pare-feu avec les exceptions
Write-Host "Réactivation du pare-feu..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Vérifier la configuration
Write-Host ""
Write-Host "=== Vérification de la configuration WinRM ===" -ForegroundColor Green
winrm get winrm/config/service
winrm enumerate winrm/config/Listener

Write-Host ""
Write-Host "=== Configuration WinRM terminée ===" -ForegroundColor Green
Write-Host "WinRM est maintenant prêt pour Packer."
