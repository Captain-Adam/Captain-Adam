# Script d'installation de l'agent QEMU Guest pour Proxmox
# Ce script installe l'agent QEMU et les drivers VirtIO

$ErrorActionPreference = "Stop"

Write-Host "=== Installation de l'agent QEMU Guest et drivers VirtIO ===" -ForegroundColor Green

# ============================================================================
# Recherche du lecteur CD-ROM VirtIO
# ============================================================================
Write-Host "Recherche de l'ISO VirtIO..."

$virtioPath = $null
$drives = Get-PSDrive -PSProvider FileSystem

foreach ($drive in $drives) {
    $testPath = Join-Path -Path $drive.Root -ChildPath "virtio-win-gt-x64.msi"
    if (Test-Path $testPath) {
        $virtioPath = $drive.Root
        Write-Host "ISO VirtIO trouvé sur: $virtioPath"
        break
    }

    # Tester aussi le chemin alternatif
    $testPath = Join-Path -Path $drive.Root -ChildPath "guest-agent\qemu-ga-x86_64.msi"
    if (Test-Path $testPath) {
        $virtioPath = $drive.Root
        Write-Host "ISO VirtIO trouvé sur: $virtioPath"
        break
    }
}

if (-not $virtioPath) {
    Write-Host "AVERTISSEMENT: ISO VirtIO non trouvé. Tentative avec le chemin par défaut E:\" -ForegroundColor Yellow
    $virtioPath = "E:\"
}

# ============================================================================
# Installation de l'agent QEMU Guest
# ============================================================================
Write-Host ""
Write-Host "Installation de l'agent QEMU Guest..."

$qemuAgentMsi = Join-Path -Path $virtioPath -ChildPath "guest-agent\qemu-ga-x86_64.msi"

if (Test-Path $qemuAgentMsi) {
    Write-Host "Installation depuis: $qemuAgentMsi"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$qemuAgentMsi`" /qn /norestart" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "Agent QEMU installé avec succès." -ForegroundColor Green
    } else {
        Write-Host "Erreur lors de l'installation de l'agent QEMU. Code: $($process.ExitCode)" -ForegroundColor Red
    }
} else {
    Write-Host "Fichier MSI de l'agent QEMU non trouvé: $qemuAgentMsi" -ForegroundColor Yellow
}

# ============================================================================
# Installation des drivers VirtIO (package complet)
# ============================================================================
Write-Host ""
Write-Host "Installation des drivers VirtIO..."

$virtioGtMsi = Join-Path -Path $virtioPath -ChildPath "virtio-win-gt-x64.msi"

if (Test-Path $virtioGtMsi) {
    Write-Host "Installation depuis: $virtioGtMsi"
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$virtioGtMsi`" /qn /norestart" -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "Drivers VirtIO installés avec succès." -ForegroundColor Green
    } else {
        Write-Host "Erreur lors de l'installation des drivers VirtIO. Code: $($process.ExitCode)" -ForegroundColor Red
    }
} else {
    Write-Host "Fichier MSI VirtIO non trouvé: $virtioGtMsi" -ForegroundColor Yellow

    # Installation manuelle des drivers individuels
    Write-Host "Tentative d'installation manuelle des drivers..."

    $driverFolders = @(
        "Balloon\2k22\amd64",
        "NetKVM\2k22\amd64",
        "vioscsi\2k22\amd64",
        "viostor\2k22\amd64",
        "vioserial\2k22\amd64",
        "viorng\2k22\amd64",
        "qxldod\2k22\amd64"
    )

    foreach ($folder in $driverFolders) {
        $driverPath = Join-Path -Path $virtioPath -ChildPath $folder
        if (Test-Path $driverPath) {
            $infFiles = Get-ChildItem -Path $driverPath -Filter "*.inf"
            foreach ($inf in $infFiles) {
                Write-Host "Installation du driver: $($inf.Name)"
                pnputil.exe /add-driver $inf.FullName /install 2>$null
            }
        }
    }
}

# ============================================================================
# Configuration du service QEMU Guest Agent
# ============================================================================
Write-Host ""
Write-Host "Configuration du service QEMU Guest Agent..."

$service = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue

if ($service) {
    Set-Service -Name "QEMU-GA" -StartupType Automatic
    Start-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
    Write-Host "Service QEMU-GA configuré et démarré." -ForegroundColor Green
} else {
    Write-Host "Service QEMU-GA non trouvé." -ForegroundColor Yellow
}

# ============================================================================
# Vérification de l'installation
# ============================================================================
Write-Host ""
Write-Host "=== Vérification de l'installation ===" -ForegroundColor Green

# Vérifier le service QEMU Guest Agent
$qemuService = Get-Service -Name "QEMU-GA" -ErrorAction SilentlyContinue
if ($qemuService) {
    Write-Host "Service QEMU Guest Agent: $($qemuService.Status)"
} else {
    Write-Host "Service QEMU Guest Agent: Non installé" -ForegroundColor Yellow
}

# Vérifier les drivers VirtIO
Write-Host ""
Write-Host "Drivers VirtIO installés:"
Get-WmiObject Win32_PnPSignedDriver | Where-Object { $_.DeviceName -like "*VirtIO*" -or $_.DeviceName -like "*Red Hat*" } | ForEach-Object {
    Write-Host "  - $($_.DeviceName)"
}

Write-Host ""
Write-Host "=== Installation de l'agent QEMU terminée ===" -ForegroundColor Green
