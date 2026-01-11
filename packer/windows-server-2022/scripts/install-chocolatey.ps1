# Script d'installation de Chocolatey et des outils de base
# Ce script installe Chocolatey et des outils utiles pour l'administration

$ErrorActionPreference = "Stop"

Write-Host "=== Installation de Chocolatey et des outils de base ===" -ForegroundColor Green

# ============================================================================
# Installation de Chocolatey
# ============================================================================
Write-Host "Installation de Chocolatey..."

# Vérifier si Chocolatey est déjà installé
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey est déjà installé."
}
else {
    # Configuration TLS
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    # Installation de Chocolatey
    $installScript = "https://community.chocolatey.org/install.ps1"
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($installScript))

    # Attendre que l'installation soit terminée
    Start-Sleep -Seconds 10

    # Rafraîchir les variables d'environnement
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Vérifier l'installation
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Erreur: Chocolatey n'a pas pu être installé." -ForegroundColor Red
    exit 1
}

Write-Host "Chocolatey version: $(choco --version)"

# ============================================================================
# Configuration de Chocolatey
# ============================================================================
Write-Host ""
Write-Host "Configuration de Chocolatey..."

# Accepter automatiquement les licences
choco feature enable -n allowGlobalConfirmation
choco feature enable -n useRememberedArgumentsForUpgrades

# ============================================================================
# Installation des outils de base
# ============================================================================
Write-Host ""
Write-Host "Installation des outils de base..."

$packages = @(
    # Outils système
    "7zip",
    "notepadplusplus",
    "sysinternals",

    # Outils réseau
    "curl",
    "wget",

    # Outils de développement (optionnels)
    # "git",
    # "vscode",
    # "python",
    # "nodejs-lts",

    # Navigateur (optionnel)
    # "googlechrome",
    # "firefox"
)

foreach ($package in $packages) {
    Write-Host "Installation de $package..."
    choco install $package -y --no-progress --limit-output

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Avertissement: Échec de l'installation de $package" -ForegroundColor Yellow
    }
}

# ============================================================================
# Installation de PowerShell 7 (optionnel)
# ============================================================================
Write-Host ""
Write-Host "Installation de PowerShell 7..."
choco install powershell-core -y --no-progress --limit-output

# ============================================================================
# Rafraîchir les variables d'environnement
# ============================================================================
Write-Host ""
Write-Host "Mise à jour des variables d'environnement..."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# ============================================================================
# Vérification des installations
# ============================================================================
Write-Host ""
Write-Host "Vérification des installations..."

$installedPackages = choco list --local-only
Write-Host "Packages installés:"
Write-Host $installedPackages

Write-Host ""
Write-Host "=== Installation de Chocolatey terminée ===" -ForegroundColor Green
