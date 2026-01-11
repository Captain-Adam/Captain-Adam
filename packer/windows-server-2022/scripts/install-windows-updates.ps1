# Script d'installation des mises à jour Windows
# Ce script installe toutes les mises à jour Windows disponibles

$ErrorActionPreference = "Stop"

Write-Host "=== Installation des mises à jour Windows ===" -ForegroundColor Green

# ============================================================================
# Installation du module PSWindowsUpdate
# ============================================================================
Write-Host "Installation du module PSWindowsUpdate..."

# Configurer NuGet comme fournisseur de packages
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# Configurer PSGallery comme source de confiance
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Installer le module PSWindowsUpdate
Install-Module -Name PSWindowsUpdate -Force -Confirm:$false

# Importer le module
Import-Module PSWindowsUpdate

# ============================================================================
# Recherche et installation des mises à jour
# ============================================================================
Write-Host "Recherche des mises à jour disponibles..."

$maxIterations = 5
$iteration = 0
$rebootRequired = $false

while ($iteration -lt $maxIterations) {
    $iteration++
    Write-Host ""
    Write-Host "=== Itération $iteration / $maxIterations ===" -ForegroundColor Yellow

    # Rechercher les mises à jour
    Write-Host "Recherche des mises à jour..."
    $updates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot

    if ($updates.Count -eq 0) {
        Write-Host "Aucune mise à jour disponible."
        break
    }

    Write-Host "Nombre de mises à jour trouvées: $($updates.Count)"

    # Afficher les mises à jour
    foreach ($update in $updates) {
        Write-Host "  - $($update.Title)"
    }

    # Installer les mises à jour
    Write-Host ""
    Write-Host "Installation des mises à jour..."
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -Verbose

    # Vérifier si un redémarrage est nécessaire
    $rebootStatus = Get-WURebootStatus -Silent
    if ($rebootStatus) {
        Write-Host "Un redémarrage est nécessaire pour terminer l'installation."
        $rebootRequired = $true

        # Redémarrer si ce n'est pas la dernière itération
        if ($iteration -lt $maxIterations) {
            Write-Host "Redémarrage du système dans 10 secondes..."
            Start-Sleep -Seconds 10
            Restart-Computer -Force
            Start-Sleep -Seconds 300  # Attendre le redémarrage
        }
    }

    Write-Host "Itération $iteration terminée."
}

# ============================================================================
# Nettoyage après les mises à jour
# ============================================================================
Write-Host ""
Write-Host "Nettoyage post-mises à jour..."

# Nettoyer le cache Windows Update
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Installation des mises à jour terminée ===" -ForegroundColor Green

if ($rebootRequired) {
    Write-Host "ATTENTION: Un redémarrage est recommandé pour finaliser les mises à jour." -ForegroundColor Yellow
}
