# Script d'installation des VMware Tools
# Ce script installe les VMware Tools sur Windows Server 2022

$ErrorActionPreference = "Stop"

Write-Host "=== Installation des VMware Tools ===" -ForegroundColor Green

# ============================================================================
# Recherche du lecteur CD-ROM avec VMware Tools
# ============================================================================
Write-Host "Recherche de l'image VMware Tools..."

$vmwareToolsPath = $null
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -eq $null }

foreach ($drive in $drives) {
    $testPath = Join-Path -Path $drive.Root -ChildPath "setup64.exe"
    if (Test-Path $testPath) {
        $vmwareToolsPath = $testPath
        Write-Host "VMware Tools trouvé sur: $($drive.Root)"
        break
    }

    $testPath = Join-Path -Path $drive.Root -ChildPath "VMwareTools\setup64.exe"
    if (Test-Path $testPath) {
        $vmwareToolsPath = $testPath
        Write-Host "VMware Tools trouvé sur: $($drive.Root)"
        break
    }
}

# ============================================================================
# Installation via PowerCLI/Web si non trouvé localement
# ============================================================================
if (-not $vmwareToolsPath) {
    Write-Host "VMware Tools non trouvé localement. Téléchargement en cours..."

    # URL de téléchargement des VMware Tools
    $vmwareToolsUrl = "https://packages.vmware.com/tools/releases/latest/windows/x64/"

    # Créer le dossier temporaire
    $tempDir = "$env:TEMP\VMwareTools"
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    # Télécharger la dernière version
    try {
        $webClient = New-Object System.Net.WebClient
        $page = $webClient.DownloadString($vmwareToolsUrl)

        # Extraire le nom du fichier .exe
        if ($page -match '(VMware-tools-[\d\.]+-[\d]+\.exe)') {
            $fileName = $Matches[1]
            $downloadUrl = "$vmwareToolsUrl$fileName"
            $downloadPath = "$tempDir\$fileName"

            Write-Host "Téléchargement de $fileName..."
            $webClient.DownloadFile($downloadUrl, $downloadPath)
            $vmwareToolsPath = $downloadPath
        }
    }
    catch {
        Write-Host "Impossible de télécharger VMware Tools: $_" -ForegroundColor Yellow
    }
}

# ============================================================================
# Installation des VMware Tools
# ============================================================================
if ($vmwareToolsPath -and (Test-Path $vmwareToolsPath)) {
    Write-Host "Installation des VMware Tools depuis: $vmwareToolsPath"

    # Arguments d'installation silencieuse
    $arguments = @(
        "/S",
        "/v`"/qn REBOOT=ReallySuppress ADDLOCAL=ALL`""
    )

    if ($vmwareToolsPath -like "*.exe") {
        # Installation depuis le fichier EXE téléchargé
        $process = Start-Process -FilePath $vmwareToolsPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    }
    else {
        # Installation depuis le CD-ROM (setup64.exe)
        $process = Start-Process -FilePath $vmwareToolsPath -ArgumentList "/S /v`"/qn REBOOT=ReallySuppress ADDLOCAL=ALL`"" -Wait -PassThru -NoNewWindow
    }

    if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
        Write-Host "VMware Tools installé avec succès." -ForegroundColor Green

        if ($process.ExitCode -eq 3010) {
            Write-Host "Un redémarrage est nécessaire pour terminer l'installation." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Erreur lors de l'installation des VMware Tools. Code de sortie: $($process.ExitCode)" -ForegroundColor Red
    }
}
else {
    Write-Host "AVERTISSEMENT: VMware Tools introuvable. L'installation est ignorée." -ForegroundColor Yellow
    Write-Host "Assurez-vous que l'image ISO VMware Tools est montée sur la VM." -ForegroundColor Yellow
}

# ============================================================================
# Vérification de l'installation
# ============================================================================
Write-Host ""
Write-Host "Vérification de l'installation..."

$vmwareToolsService = Get-Service -Name "VMTools" -ErrorAction SilentlyContinue
if ($vmwareToolsService) {
    Write-Host "Service VMware Tools: $($vmwareToolsService.Status)" -ForegroundColor Green

    # Démarrer le service s'il n'est pas en cours d'exécution
    if ($vmwareToolsService.Status -ne "Running") {
        Start-Service -Name "VMTools" -ErrorAction SilentlyContinue
    }
}
else {
    Write-Host "Service VMware Tools non trouvé." -ForegroundColor Yellow
}

# Nettoyage
if (Test-Path "$env:TEMP\VMwareTools") {
    Remove-Item -Path "$env:TEMP\VMwareTools" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Installation des VMware Tools terminée ===" -ForegroundColor Green
