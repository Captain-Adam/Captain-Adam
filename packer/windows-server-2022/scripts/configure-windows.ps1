# Script de configuration de base Windows Server 2022
# Ce script configure les paramètres de base du système

$ErrorActionPreference = "Stop"

Write-Host "=== Configuration de base Windows Server 2022 ===" -ForegroundColor Green

# ============================================================================
# Désactiver l'expiration du mot de passe Administrateur
# ============================================================================
Write-Host "Désactivation de l'expiration du mot de passe Administrateur..."
Set-LocalUser -Name "Administrator" -PasswordNeverExpires $true

# ============================================================================
# Désactiver Server Manager au démarrage
# ============================================================================
Write-Host "Désactivation de Server Manager au démarrage..."
$regPath = "HKLM:\SOFTWARE\Microsoft\ServerManager"
if (Test-Path $regPath) {
    Set-ItemProperty -Path $regPath -Name "DoNotOpenServerManagerAtLogon" -Value 1
}

# ============================================================================
# Activer Remote Desktop
# ============================================================================
Write-Host "Activation de Remote Desktop..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup "Bureau à distance" -ErrorAction SilentlyContinue

# ============================================================================
# Configurer les paramètres d'alimentation (High Performance)
# ============================================================================
Write-Host "Configuration du plan d'alimentation Haute performance..."
$powerPlan = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object { $_.ElementName -eq "High performance" -or $_.ElementName -eq "Performances élevées" }
if ($powerPlan) {
    powercfg /setactive $powerPlan.InstanceID.Split('"')[1]
}

# Désactiver l'hibernation
Write-Host "Désactivation de l'hibernation..."
powercfg /hibernate off

# ============================================================================
# Configurer les mises à jour Windows
# ============================================================================
Write-Host "Configuration de Windows Update..."
$WUSettings = (New-Object -ComObject Microsoft.Update.AutoUpdate).EnableService()

# ============================================================================
# Désactiver les tâches inutiles
# ============================================================================
Write-Host "Désactivation des tâches de maintenance inutiles..."
$tasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
)

foreach ($task in $tasksToDisable) {
    schtasks /Change /TN $task /Disable 2>$null
}

# ============================================================================
# Configurer les services essentiels
# ============================================================================
Write-Host "Configuration des services..."

# Démarrage automatique des services essentiels
$servicesToAutoStart = @("WinRM", "W32Time", "RemoteRegistry")
foreach ($service in $servicesToAutoStart) {
    Set-Service -Name $service -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name $service -ErrorAction SilentlyContinue
}

# ============================================================================
# Configurer le fuseau horaire et NTP
# ============================================================================
Write-Host "Configuration du fuseau horaire et NTP..."
Set-TimeZone -Name "Romance Standard Time"
w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update
Restart-Service W32Time
w32tm /resync

# ============================================================================
# Désactiver IPv6 si non requis
# ============================================================================
# Write-Host "Désactivation de IPv6..."
# Get-NetAdapterBinding | Where-Object { $_.ComponentID -eq "ms_tcpip6" } | Disable-NetAdapterBinding -ComponentID ms_tcpip6

# ============================================================================
# Configuration du registre pour optimisation
# ============================================================================
Write-Host "Optimisation du registre..."

# Augmenter les descripteurs de fichiers
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $regPath -Name "SystemPages" -Value 0

# Désactiver la création du fichier d'échange automatique
# $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
# Set-ItemProperty -Path $regPath -Name "PagingFiles" -Value "C:\pagefile.sys 4096 8192"

# ============================================================================
# Installation des fonctionnalités Windows utiles
# ============================================================================
Write-Host "Installation des fonctionnalités Windows..."

# PowerShell 7 si disponible
# winget install --id Microsoft.Powershell --source winget -e --accept-source-agreements --accept-package-agreements

# Telnet Client (pour debug)
Install-WindowsFeature -Name Telnet-Client -ErrorAction SilentlyContinue

# ============================================================================
# Configuration de la politique d'exécution PowerShell
# ============================================================================
Write-Host "Configuration de la politique d'exécution PowerShell..."
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

Write-Host ""
Write-Host "=== Configuration de base terminée ===" -ForegroundColor Green
