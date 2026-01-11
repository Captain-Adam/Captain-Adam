# Script de nettoyage final pour Windows Server 2022
# Ce script nettoie le système avant la création du template

$ErrorActionPreference = "SilentlyContinue"

Write-Host "=== Nettoyage final du système ===" -ForegroundColor Green

# ============================================================================
# Nettoyage des fichiers temporaires
# ============================================================================
Write-Host "Nettoyage des fichiers temporaires..."

# Dossiers temporaires Windows
$tempFolders = @(
    "$env:TEMP",
    "$env:windir\Temp",
    "$env:windir\Prefetch",
    "$env:windir\SoftwareDistribution\Download",
    "$env:LOCALAPPDATA\Temp"
)

foreach ($folder in $tempFolders) {
    if (Test-Path $folder) {
        Write-Host "Nettoyage de: $folder"
        Remove-Item -Path "$folder\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# Nettoyage du cache Windows Update
# ============================================================================
Write-Host "Nettoyage du cache Windows Update..."
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:windir\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

# ============================================================================
# Nettoyage du Disk Cleanup
# ============================================================================
Write-Host "Exécution du nettoyage de disque..."

# Configuration du nettoyage automatique
$cleanupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$cleanupItems = @(
    "Active Setup Temp Folders",
    "Downloaded Program Files",
    "Internet Cache Files",
    "Memory Dump Files",
    "Old ChkDsk Files",
    "Previous Installations",
    "Recycle Bin",
    "Setup Log Files",
    "System error memory dump files",
    "System error minidump files",
    "Temporary Files",
    "Temporary Setup Files",
    "Thumbnail Cache",
    "Update Cleanup",
    "Upgrade Discarded Files",
    "Windows Error Reporting Archive Files",
    "Windows Error Reporting Queue Files",
    "Windows Error Reporting System Archive Files",
    "Windows Error Reporting System Queue Files",
    "Windows Upgrade Log Files"
)

foreach ($item in $cleanupItems) {
    $itemKey = "$cleanupKey\$item"
    if (Test-Path $itemKey) {
        Set-ItemProperty -Path $itemKey -Name "StateFlags0100" -Value 2 -Type DWord -Force
    }
}

# Exécuter le nettoyage
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:100" -Wait -NoNewWindow -ErrorAction SilentlyContinue

# ============================================================================
# Nettoyage des journaux d'événements
# ============================================================================
Write-Host "Nettoyage des journaux d'événements..."
wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }

# ============================================================================
# Nettoyage du cache Chocolatey
# ============================================================================
Write-Host "Nettoyage du cache Chocolatey..."
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Remove-Item -Path "$env:TEMP\chocolatey" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\ProgramData\chocolatey\logs\*" -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Nettoyage du cache NuGet
# ============================================================================
Write-Host "Nettoyage du cache NuGet..."
Remove-Item -Path "$env:LOCALAPPDATA\NuGet\Cache" -Recurse -Force -ErrorAction SilentlyContinue

# ============================================================================
# Nettoyage de l'historique PowerShell
# ============================================================================
Write-Host "Nettoyage de l'historique PowerShell..."
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -Force -ErrorAction SilentlyContinue

# ============================================================================
# Suppression des fichiers inutiles
# ============================================================================
Write-Host "Suppression des fichiers inutiles..."

# Fichiers de log Windows
Get-ChildItem -Path "$env:windir\Logs" -Recurse -File | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:windir\Panther" -Recurse -File | Remove-Item -Force -ErrorAction SilentlyContinue

# Fichiers CBS logs
Remove-Item -Path "$env:windir\Logs\CBS\*" -Force -ErrorAction SilentlyContinue

# ============================================================================
# Optimisation du WinSxS
# ============================================================================
Write-Host "Optimisation du magasin de composants (WinSxS)..."
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

# ============================================================================
# Désactiver les fonctionnalités de télémétrie (optionnel)
# ============================================================================
Write-Host "Désactivation de la télémétrie..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

# ============================================================================
# Réinitialiser les compteurs de performance
# ============================================================================
Write-Host "Réinitialisation des compteurs de performance..."
lodctr /R 2>$null

# ============================================================================
# Défragmentation (pour les disques HDD uniquement)
# ============================================================================
Write-Host "Optimisation du disque..."
Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue

# ============================================================================
# Vider la corbeille
# ============================================================================
Write-Host "Vidage de la corbeille..."
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

# ============================================================================
# Zéroiser l'espace libre (pour réduire la taille du VMDK)
# ============================================================================
Write-Host "Préparation pour la réduction de l'image..."

# Créer un fichier temporaire pour remplir l'espace libre avec des zéros
$zeroFilePath = "C:\zero.tmp"
try {
    Write-Host "Création du fichier de zéros (cela peut prendre du temps)..."
    $stream = [System.IO.File]::Create($zeroFilePath)
    $buffer = New-Object byte[] 1048576  # 1 MB buffer

    try {
        while ($true) {
            $stream.Write($buffer, 0, $buffer.Length)
        }
    }
    catch {
        # Le disque est plein, c'est normal
    }
    finally {
        $stream.Close()
    }
}
catch {
    # Ignorer les erreurs
}
finally {
    # Supprimer le fichier de zéros
    Remove-Item -Path $zeroFilePath -Force -ErrorAction SilentlyContinue
}

# ============================================================================
# Désactiver l'auto-logon
# ============================================================================
Write-Host "Désactivation de l'auto-logon..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $regPath -Name "AutoAdminLogon" -Value "0" -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -Force -ErrorAction SilentlyContinue

# ============================================================================
# Statistiques finales
# ============================================================================
Write-Host ""
Write-Host "=== Nettoyage terminé ===" -ForegroundColor Green

# Afficher l'espace disque disponible
$disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
$totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
$usedSpaceGB = $totalSpaceGB - $freeSpaceGB

Write-Host ""
Write-Host "Statistiques du disque C:\"
Write-Host "  Espace total: $totalSpaceGB GB"
Write-Host "  Espace utilisé: $usedSpaceGB GB"
Write-Host "  Espace libre: $freeSpaceGB GB"
Write-Host ""
Write-Host "Le système est prêt pour Sysprep." -ForegroundColor Green
