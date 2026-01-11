<#
.SYNOPSIS
    Script de décommissionnement complet d'un serveur RDSH dans une ferme RDS.

.DESCRIPTION
    Ce script permet de retirer proprement un serveur RDSH d'une ferme RDS en suivant les étapes :
    1. Vérification des prérequis et permissions
    2. Mise en mode "drain" (arrêt des nouvelles connexions)
    3. Attente ou déconnexion forcée des sessions utilisateurs
    4. Retrait du serveur de la collection RDS
    5. Suppression du rôle RDSH (optionnel)
    6. Nettoyage des configurations

.PARAMETER RDSHServer
    Nom FQDN du serveur RDSH à décommissionner

.PARAMETER ConnectionBroker
    Nom FQDN du Connection Broker RDS

.PARAMETER CollectionName
    Nom de la collection RDS dont le serveur fait partie

.PARAMETER ForceLogoff
    Force la déconnexion des sessions utilisateurs actives

.PARAMETER WaitTimeout
    Temps d'attente maximum en minutes pour la déconnexion des sessions (défaut: 30)

.PARAMETER RemoveRole
    Supprime le rôle RDSH du serveur après décommissionnement

.PARAMETER LogPath
    Chemin du fichier de log (défaut: C:\Logs\RDSH-Decommission.log)

.EXAMPLE
    .\Decommission-RDSHServer.ps1 -RDSHServer "rdsh01.contoso.com" -ConnectionBroker "rdscb.contoso.com" -CollectionName "Production"

.EXAMPLE
    .\Decommission-RDSHServer.ps1 -RDSHServer "rdsh01.contoso.com" -ConnectionBroker "rdscb.contoso.com" -CollectionName "Production" -ForceLogoff -RemoveRole

.NOTES
    Author: Captain-Adam
    Version: 1.0
    Requires: Module RemoteDesktop, Droits administrateur
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$RDSHServer,

    [Parameter(Mandatory=$true)]
    [string]$ConnectionBroker,

    [Parameter(Mandatory=$true)]
    [string]$CollectionName,

    [Parameter(Mandatory=$false)]
    [switch]$ForceLogoff,

    [Parameter(Mandatory=$false)]
    [int]$WaitTimeout = 30,

    [Parameter(Mandatory=$false)]
    [switch]$RemoveRole,

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs\RDSH-Decommission.log"
)

#region Functions

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Créer le dossier de logs si nécessaire
    $logDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Écrire dans le fichier de log
    Add-Content -Path $LogPath -Value $logMessage

    # Afficher dans la console avec couleur
    switch ($Level) {
        'INFO'    { Write-Host $logMessage -ForegroundColor Cyan }
        'WARNING' { Write-Host $logMessage -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logMessage -ForegroundColor Red }
        'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
    }
}

function Test-Prerequisites {
    Write-Log "Vérification des prérequis..." -Level INFO

    # Vérifier les permissions administrateur
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Ce script nécessite des droits administrateur." -Level ERROR
        return $false
    }

    # Vérifier le module RemoteDesktop
    if (-not (Get-Module -ListAvailable -Name RemoteDesktop)) {
        Write-Log "Le module RemoteDesktop n'est pas installé." -Level ERROR
        return $false
    }

    Import-Module RemoteDesktop -ErrorAction Stop
    Write-Log "Module RemoteDesktop chargé avec succès." -Level SUCCESS

    # Vérifier la connectivité au Connection Broker
    if (-not (Test-Connection -ComputerName $ConnectionBroker -Count 2 -Quiet)) {
        Write-Log "Impossible de joindre le Connection Broker: $ConnectionBroker" -Level ERROR
        return $false
    }

    # Vérifier la connectivité au serveur RDSH
    if (-not (Test-Connection -ComputerName $RDSHServer -Count 2 -Quiet)) {
        Write-Log "Impossible de joindre le serveur RDSH: $RDSHServer" -Level ERROR
        return $false
    }

    Write-Log "Tous les prérequis sont satisfaits." -Level SUCCESS
    return $true
}

function Get-RDSHSessions {
    param(
        [string]$ServerName
    )

    try {
        $sessions = Get-RDUserSession -ConnectionBroker $ConnectionBroker | Where-Object { $_.HostServer -eq $ServerName }
        return $sessions
    }
    catch {
        Write-Log "Erreur lors de la récupération des sessions: $_" -Level ERROR
        return $null
    }
}

function Set-RDSHDrainMode {
    param(
        [string]$ServerName,
        [bool]$Enable
    )

    try {
        $drainMode = if ($Enable) { 1 } else { 0 }
        Set-RDSessionHost -SessionHost $ServerName -ConnectionBroker $ConnectionBroker -NewConnectionAllowed NotUntilReboot
        Write-Log "Mode drain activé sur $ServerName - Nouvelles connexions bloquées." -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Erreur lors de l'activation du mode drain: $_" -Level ERROR
        return $false
    }
}

function Wait-ForSessionsToEnd {
    param(
        [string]$ServerName,
        [int]$TimeoutMinutes
    )

    Write-Log "Attente de la déconnexion des sessions (timeout: $TimeoutMinutes minutes)..." -Level INFO

    $endTime = (Get-Date).AddMinutes($TimeoutMinutes)

    while ((Get-Date) -lt $endTime) {
        $sessions = Get-RDSHSessions -ServerName $ServerName

        if ($null -eq $sessions -or $sessions.Count -eq 0) {
            Write-Log "Toutes les sessions sont terminées." -Level SUCCESS
            return $true
        }

        $activeCount = $sessions.Count
        Write-Log "Sessions actives restantes: $activeCount" -Level INFO
        Write-Host "  Sessions en cours:"
        foreach ($session in $sessions) {
            Write-Host "    - Utilisateur: $($session.UserName), État: $($session.SessionState)"
        }

        Start-Sleep -Seconds 30
    }

    Write-Log "Timeout atteint. Sessions toujours actives." -Level WARNING
    return $false
}

function Disconnect-RDSHSessions {
    param(
        [string]$ServerName,
        [bool]$Force
    )

    try {
        $sessions = Get-RDSHSessions -ServerName $ServerName

        if ($null -eq $sessions -or $sessions.Count -eq 0) {
            Write-Log "Aucune session active à déconnecter." -Level INFO
            return $true
        }

        Write-Log "Déconnexion de $($sessions.Count) session(s)..." -Level WARNING

        foreach ($session in $sessions) {
            try {
                if ($Force) {
                    Invoke-RDUserLogoff -HostServer $session.HostServer -UnifiedSessionID $session.UnifiedSessionId -ConnectionBroker $ConnectionBroker -Force
                    Write-Log "Session forcée à se déconnecter: $($session.UserName)" -Level WARNING
                }
                else {
                    # Envoyer un message à l'utilisateur avant déconnexion
                    $message = "Votre session va être déconnectée pour maintenance du serveur. Veuillez sauvegarder votre travail."
                    Send-RDUserMessage -HostServer $session.HostServer -UnifiedSessionID $session.UnifiedSessionId -MessageTitle "Maintenance serveur" -MessageBody $message -ConnectionBroker $ConnectionBroker
                    Start-Sleep -Seconds 60
                    Invoke-RDUserLogoff -HostServer $session.HostServer -UnifiedSessionID $session.UnifiedSessionId -ConnectionBroker $ConnectionBroker
                    Write-Log "Session déconnectée: $($session.UserName)" -Level INFO
                }
            }
            catch {
                Write-Log "Erreur lors de la déconnexion de la session $($session.UserName): $_" -Level ERROR
            }
        }

        return $true
    }
    catch {
        Write-Log "Erreur lors de la déconnexion des sessions: $_" -Level ERROR
        return $false
    }
}

function Remove-RDSHFromCollection {
    param(
        [string]$ServerName,
        [string]$Collection
    )

    try {
        Write-Log "Retrait du serveur $ServerName de la collection $Collection..." -Level INFO

        # Vérifier que le serveur fait partie de la collection
        $sessionHosts = Get-RDSessionHost -CollectionName $Collection -ConnectionBroker $ConnectionBroker
        $serverInCollection = $sessionHosts | Where-Object { $_.SessionHost -eq $ServerName }

        if ($null -eq $serverInCollection) {
            Write-Log "Le serveur $ServerName ne fait pas partie de la collection $Collection." -Level WARNING
            return $false
        }

        # Retirer le serveur
        Remove-RDSessionHost -SessionHost $ServerName -ConnectionBroker $ConnectionBroker -Force
        Write-Log "Serveur $ServerName retiré de la collection avec succès." -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Erreur lors du retrait du serveur de la collection: $_" -Level ERROR
        return $false
    }
}

function Remove-RDSHRole {
    param(
        [string]$ServerName
    )

    try {
        Write-Log "Suppression du rôle RDSH sur $ServerName..." -Level INFO

        $result = Invoke-Command -ComputerName $ServerName -ScriptBlock {
            try {
                # Supprimer le rôle RDS-RD-Server
                Remove-WindowsFeature -Name RDS-RD-Server -IncludeManagementTools
                return @{Success=$true; Message="Rôle supprimé avec succès"}
            }
            catch {
                return @{Success=$false; Message=$_.Exception.Message}
            }
        }

        if ($result.Success) {
            Write-Log "Rôle RDSH supprimé avec succès. Un redémarrage peut être nécessaire." -Level SUCCESS
            return $true
        }
        else {
            Write-Log "Erreur lors de la suppression du rôle: $($result.Message)" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "Erreur lors de la suppression du rôle RDSH: $_" -Level ERROR
        return $false
    }
}

function Invoke-CleanupTasks {
    param(
        [string]$ServerName
    )

    Write-Log "Exécution des tâches de nettoyage sur $ServerName..." -Level INFO

    try {
        Invoke-Command -ComputerName $ServerName -ScriptBlock {
            # Nettoyer les profils temporaires
            $profiles = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.Special -eq $false -and $_.Loaded -eq $false }
            foreach ($profile in $profiles) {
                try {
                    $profile.Delete()
                }
                catch {
                    Write-Warning "Impossible de supprimer le profil: $($profile.LocalPath)"
                }
            }

            # Nettoyer les fichiers temporaires
            Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "C:\Users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

            # Nettoyer les logs RDS anciens
            $logPath = "C:\Windows\System32\LogFiles\RDSH"
            if (Test-Path $logPath) {
                Get-ChildItem -Path $logPath -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Log "Tâches de nettoyage terminées." -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Erreur lors du nettoyage: $_" -Level WARNING
        return $false
    }
}

#endregion

#region Main Script

Write-Log "========================================" -Level INFO
Write-Log "Début du décommissionnement du serveur RDSH" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Serveur RDSH: $RDSHServer" -Level INFO
Write-Log "Connection Broker: $ConnectionBroker" -Level INFO
Write-Log "Collection: $CollectionName" -Level INFO
Write-Log "========================================" -Level INFO

# Étape 1: Vérification des prérequis
if (-not (Test-Prerequisites)) {
    Write-Log "Échec de la vérification des prérequis. Arrêt du script." -Level ERROR
    exit 1
}

# Étape 2: Vérifier que le serveur existe dans la collection
try {
    $sessionHosts = Get-RDSessionHost -CollectionName $CollectionName -ConnectionBroker $ConnectionBroker -ErrorAction Stop
    $targetServer = $sessionHosts | Where-Object { $_.SessionHost -eq $RDSHServer }

    if ($null -eq $targetServer) {
        Write-Log "Le serveur $RDSHServer n'existe pas dans la collection $CollectionName." -Level ERROR
        exit 1
    }

    Write-Log "Serveur trouvé dans la collection. État actuel: $($targetServer.NewConnectionAllowed)" -Level INFO
}
catch {
    Write-Log "Erreur lors de la vérification du serveur: $_" -Level ERROR
    exit 1
}

# Étape 3: Afficher les sessions actives
$currentSessions = Get-RDSHSessions -ServerName $RDSHServer
if ($null -ne $currentSessions -and $currentSessions.Count -gt 0) {
    Write-Log "Sessions actives détectées: $($currentSessions.Count)" -Level WARNING
    foreach ($session in $currentSessions) {
        Write-Log "  - Utilisateur: $($session.UserName), État: $($session.SessionState), Depuis: $($session.UnifiedSessionId)" -Level INFO
    }
}
else {
    Write-Log "Aucune session active détectée." -Level INFO
}

# Étape 4: Confirmation utilisateur
if (-not $PSCmdlet.ShouldProcess($RDSHServer, "Décommissionner le serveur RDSH")) {
    Write-Log "Opération annulée par l'utilisateur." -Level WARNING
    exit 0
}

# Étape 5: Activer le mode drain
Write-Log "Activation du mode drain..." -Level INFO
if (-not (Set-RDSHDrainMode -ServerName $RDSHServer -Enable $true)) {
    Write-Log "Impossible d'activer le mode drain. Continuer quand même? (O/N)" -Level WARNING
    $response = Read-Host
    if ($response -ne 'O') {
        Write-Log "Opération annulée." -Level WARNING
        exit 1
    }
}

# Étape 6: Gestion des sessions
if ($ForceLogoff) {
    Write-Log "Mode ForceLogoff activé. Déconnexion immédiate des sessions." -Level WARNING
    Disconnect-RDSHSessions -ServerName $RDSHServer -Force $true
}
else {
    # Attendre que les sessions se terminent naturellement
    $sessionsEnded = Wait-ForSessionsToEnd -ServerName $RDSHServer -TimeoutMinutes $WaitTimeout

    if (-not $sessionsEnded) {
        $remainingSessions = Get-RDSHSessions -ServerName $RDSHServer
        Write-Log "Il reste $($remainingSessions.Count) session(s) active(s) après le timeout." -Level WARNING
        Write-Log "Voulez-vous forcer la déconnexion? (O/N)" -Level WARNING
        $response = Read-Host

        if ($response -eq 'O') {
            Disconnect-RDSHSessions -ServerName $RDSHServer -Force $true
        }
        else {
            Write-Log "Opération annulée. Sessions toujours actives." -Level WARNING
            exit 1
        }
    }
}

# Attendre quelques secondes pour s'assurer que toutes les sessions sont fermées
Start-Sleep -Seconds 10

# Étape 7: Retirer le serveur de la collection
Write-Log "Retrait du serveur de la collection RDS..." -Level INFO
if (Remove-RDSHFromCollection -ServerName $RDSHServer -Collection $CollectionName) {
    Write-Log "Serveur retiré de la collection avec succès." -Level SUCCESS
}
else {
    Write-Log "Échec du retrait du serveur de la collection." -Level ERROR
    exit 1
}

# Étape 8: Nettoyage
Write-Log "Exécution des tâches de nettoyage..." -Level INFO
Invoke-CleanupTasks -ServerName $RDSHServer

# Étape 9: Suppression du rôle (optionnel)
if ($RemoveRole) {
    Write-Log "Suppression du rôle RDSH demandée..." -Level INFO
    if (Remove-RDSHRole -ServerName $RDSHServer) {
        Write-Log "Rôle RDSH supprimé. Le serveur doit être redémarré." -Level SUCCESS
        Write-Log "Voulez-vous redémarrer le serveur maintenant? (O/N)" -Level WARNING
        $response = Read-Host

        if ($response -eq 'O') {
            Write-Log "Redémarrage du serveur $RDSHServer..." -Level WARNING
            Restart-Computer -ComputerName $RDSHServer -Force
            Write-Log "Commande de redémarrage envoyée." -Level SUCCESS
        }
    }
    else {
        Write-Log "Échec de la suppression du rôle RDSH." -Level ERROR
    }
}

# Résumé final
Write-Log "========================================" -Level SUCCESS
Write-Log "Décommissionnement terminé avec succès!" -Level SUCCESS
Write-Log "========================================" -Level SUCCESS
Write-Log "Serveur: $RDSHServer" -Level INFO
Write-Log "Collection: $CollectionName" -Level INFO
Write-Log "Log complet disponible: $LogPath" -Level INFO
Write-Log "========================================" -Level SUCCESS

# Actions post-décommissionnement recommandées
Write-Host "`n"
Write-Host "Actions recommandées après décommissionnement:" -ForegroundColor Cyan
Write-Host "  1. Vérifier la répartition de charge sur les serveurs restants" -ForegroundColor White
Write-Host "  2. Surveiller les performances de la ferme RDS" -ForegroundColor White
Write-Host "  3. Mettre à jour la documentation de l'infrastructure" -ForegroundColor White
Write-Host "  4. Sauvegarder les logs avant suppression du serveur" -ForegroundColor White
if ($RemoveRole) {
    Write-Host "  5. Le serveur peut maintenant être réaffecté ou éteint" -ForegroundColor White
}
Write-Host "`n"

#endregion
