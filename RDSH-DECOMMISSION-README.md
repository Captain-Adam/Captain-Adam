# Script de Décommissionnement RDSH

## Description

Ce script PowerShell permet de décommissionner proprement et complètement un serveur RDSH (Remote Desktop Session Host) d'une ferme RDS (Remote Desktop Services).

## Fonctionnalités

Le script effectue automatiquement les opérations suivantes :

1. ✅ **Vérification des prérequis**
   - Droits administrateur
   - Module PowerShell RemoteDesktop
   - Connectivité réseau

2. 🔒 **Activation du mode "drain"**
   - Empêche les nouvelles connexions utilisateur
   - Préserve les sessions existantes

3. 👥 **Gestion des sessions utilisateurs**
   - Affichage des sessions actives
   - Notification aux utilisateurs
   - Attente ou déconnexion forcée selon les paramètres

4. 🔌 **Retrait de la collection RDS**
   - Suppression du serveur de la collection
   - Vérification de l'état

5. 🧹 **Nettoyage du système**
   - Suppression des profils temporaires
   - Nettoyage des fichiers temporaires
   - Nettoyage des logs RDS anciens

6. ⚙️ **Suppression du rôle (optionnel)**
   - Désinstallation du rôle RDSH
   - Option de redémarrage

7. 📝 **Logging complet**
   - Traçabilité de toutes les opérations
   - Fichier de log horodaté

## Prérequis

- **Système d'exploitation** : Windows Server 2012 R2 ou supérieur
- **Permissions** : Administrateur local + droits sur la ferme RDS
- **Module PowerShell** : RemoteDesktop
- **Accès réseau** : Connectivité au Connection Broker et au serveur RDSH cible

## Installation du module RemoteDesktop

Si le module n'est pas installé :

```powershell
# Sur le serveur Connection Broker
Install-WindowsFeature -Name RDS-Connection-Broker -IncludeManagementTools

# Ou via RSAT sur un poste d'administration
Add-WindowsCapability -Online -Name Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0
```

## Syntaxe

```powershell
.\Decommission-RDSHServer.ps1
    -RDSHServer <String>
    -ConnectionBroker <String>
    -CollectionName <String>
    [-ForceLogoff]
    [-WaitTimeout <Int32>]
    [-RemoveRole]
    [-LogPath <String>]
    [-WhatIf]
    [-Confirm]
```

## Paramètres

| Paramètre | Type | Obligatoire | Description |
|-----------|------|-------------|-------------|
| `RDSHServer` | String | Oui | Nom FQDN du serveur RDSH à décommissionner (ex: rdsh01.contoso.com) |
| `ConnectionBroker` | String | Oui | Nom FQDN du Connection Broker RDS (ex: rdscb.contoso.com) |
| `CollectionName` | String | Oui | Nom de la collection RDS |
| `ForceLogoff` | Switch | Non | Force la déconnexion immédiate des sessions utilisateurs |
| `WaitTimeout` | Int32 | Non | Temps d'attente maximum en minutes (défaut: 30) |
| `RemoveRole` | Switch | Non | Supprime le rôle RDSH après décommissionnement |
| `LogPath` | String | Non | Chemin du fichier de log (défaut: C:\Logs\RDSH-Decommission.log) |

## Exemples d'utilisation

### Exemple 1 : Décommissionnement standard (attente des sessions)

```powershell
.\Decommission-RDSHServer.ps1 `
    -RDSHServer "rdsh01.contoso.com" `
    -ConnectionBroker "rdscb.contoso.com" `
    -CollectionName "Production"
```

Ce mode :
- Active le mode drain
- Attend jusqu'à 30 minutes que les utilisateurs se déconnectent
- Demande confirmation si des sessions restent actives

### Exemple 2 : Décommissionnement avec déconnexion forcée

```powershell
.\Decommission-RDSHServer.ps1 `
    -RDSHServer "rdsh01.contoso.com" `
    -ConnectionBroker "rdscb.contoso.com" `
    -CollectionName "Production" `
    -ForceLogoff
```

Ce mode :
- Envoie un message d'avertissement aux utilisateurs
- Déconnecte forcément toutes les sessions après 60 secondes

### Exemple 3 : Décommissionnement complet avec suppression du rôle

```powershell
.\Decommission-RDSHServer.ps1 `
    -RDSHServer "rdsh01.contoso.com" `
    -ConnectionBroker "rdscb.contoso.com" `
    -CollectionName "Production" `
    -ForceLogoff `
    -RemoveRole
```

Ce mode effectue un décommissionnement complet incluant la désinstallation du rôle RDSH.

### Exemple 4 : Avec timeout personnalisé

```powershell
.\Decommission-RDSHServer.ps1 `
    -RDSHServer "rdsh01.contoso.com" `
    -ConnectionBroker "rdscb.contoso.com" `
    -CollectionName "Production" `
    -WaitTimeout 60 `
    -LogPath "D:\Logs\decommission-rdsh01.log"
```

Attend jusqu'à 60 minutes avant de demander confirmation pour forcer les déconnexions.

### Exemple 5 : Mode WhatIf (simulation)

```powershell
.\Decommission-RDSHServer.ps1 `
    -RDSHServer "rdsh01.contoso.com" `
    -ConnectionBroker "rdscb.contoso.com" `
    -CollectionName "Production" `
    -WhatIf
```

Simule les opérations sans les exécuter réellement.

## Processus de décommissionnement

### Timeline recommandée

```
J-7  : Planification et communication aux utilisateurs
J-3  : Vérification de la ferme RDS et des capacités restantes
J-1  : Activation du mode drain (manuel ou via script)
Jour J : Exécution du script de décommissionnement
J+1  : Vérification de la ferme et monitoring
```

### Diagramme de flux

```
Début
  ↓
Vérification prérequis
  ↓
Activation mode drain
  ↓
Sessions actives ? ─── Non ──→ Retrait collection
  ↓                              ↓
 Oui                        Nettoyage
  ↓                              ↓
ForceLogoff ? ─ Oui ─→ Déco forcée
  ↓                              ↓
 Non                      Suppression rôle ?
  ↓                              ↓
Attente timeout              Terminé
  ↓
Sessions restantes ?
  ↓
Demande confirmation
  ↓
Retrait collection
  ↓
...
```

## Gestion des erreurs

Le script gère les erreurs suivantes :

- ❌ Absence de droits administrateur → Arrêt immédiat
- ❌ Module RemoteDesktop manquant → Arrêt avec message
- ❌ Serveur inaccessible → Arrêt avec message
- ❌ Serveur non trouvé dans collection → Arrêt avec message
- ⚠️ Échec mode drain → Demande confirmation pour continuer
- ⚠️ Sessions actives après timeout → Demande confirmation

## Sécurité et bonnes pratiques

### Avant l'exécution

1. **Sauvegarde** : Sauvegarder la configuration de la ferme RDS
   ```powershell
   Export-RDDeploymentConfiguration -ConnectionBroker "rdscb.contoso.com" -Path "C:\Backup\RDS-Config.xml"
   ```

2. **Vérification de capacité** : S'assurer que la ferme peut absorber la charge
   ```powershell
   Get-RDSessionHost -CollectionName "Production" -ConnectionBroker "rdscb.contoso.com" |
       Select SessionHost, ActiveSessions, @{N="Capacity";E={100}}
   ```

3. **Communication** : Informer les utilisateurs de la maintenance planifiée

### Pendant l'exécution

- ✅ Exécuter en dehors des heures de pointe si possible
- ✅ Surveiller le fichier de log en temps réel
- ✅ Avoir un plan de rollback préparé

### Après l'exécution

1. **Vérification de la ferme**
   ```powershell
   Get-RDSessionHost -CollectionName "Production" -ConnectionBroker "rdscb.contoso.com"
   ```

2. **Test de connexion** : Vérifier qu'un utilisateur peut se connecter

3. **Monitoring** : Surveiller les performances pendant 24-48h

4. **Documentation** : Mettre à jour la documentation d'infrastructure

## Logs

Le script génère un fichier de log détaillé avec horodatage :

```
[2026-01-11 14:30:00] [INFO] Début du décommissionnement du serveur RDSH
[2026-01-11 14:30:01] [SUCCESS] Module RemoteDesktop chargé avec succès
[2026-01-11 14:30:05] [WARNING] Sessions actives détectées: 3
[2026-01-11 14:30:10] [SUCCESS] Mode drain activé sur rdsh01.contoso.com
[2026-01-11 14:35:00] [INFO] Sessions actives restantes: 1
[2026-01-11 14:40:00] [SUCCESS] Toutes les sessions sont terminées
[2026-01-11 14:40:15] [SUCCESS] Serveur rdsh01.contoso.com retiré de la collection
[2026-01-11 14:40:30] [SUCCESS] Décommissionnement terminé avec succès!
```

## Dépannage

### Problème : "Module RemoteDesktop non trouvé"

**Solution** :
```powershell
# Installer les outils de gestion RDS
Install-WindowsFeature RSAT-RDS-Tools
Import-Module RemoteDesktop
```

### Problème : "Accès refusé"

**Solution** :
- Vérifier les droits administrateur local
- Vérifier les droits sur la ferme RDS
- Exécuter PowerShell en tant qu'administrateur

### Problème : Les sessions ne se déconnectent pas

**Solution** :
- Utiliser le paramètre `-ForceLogoff`
- Vérifier manuellement avec `qwinsta /server:rdsh01`
- En dernier recours, utiliser `logoff` depuis le Connection Broker

### Problème : Impossible de retirer le serveur de la collection

**Solution** :
```powershell
# Vérifier l'état du serveur
Get-RDSessionHost -CollectionName "Production" -ConnectionBroker "rdscb.contoso.com"

# Forcer le retrait si nécessaire
Remove-RDSessionHost -SessionHost "rdsh01.contoso.com" -ConnectionBroker "rdscb.contoso.com" -Force
```

## Rollback

Si vous devez annuler le décommissionnement :

```powershell
# Ré-ajouter le serveur à la collection
Add-RDSessionHost -CollectionName "Production" `
    -SessionHost "rdsh01.contoso.com" `
    -ConnectionBroker "rdscb.contoso.com"

# Réactiver les nouvelles connexions
Set-RDSessionHost -SessionHost "rdsh01.contoso.com" `
    -ConnectionBroker "rdscb.contoso.com" `
    -NewConnectionAllowed Yes
```

## Scripts complémentaires

### Vérifier l'état de la ferme

```powershell
# Obtenir l'état de tous les serveurs RDSH
Get-RDSessionHost -ConnectionBroker "rdscb.contoso.com" |
    Select-Object SessionHost, ActiveSessions, NewConnectionAllowed |
    Format-Table -AutoSize
```

### Sauvegarder la configuration avant décommissionnement

```powershell
$date = Get-Date -Format "yyyyMMdd-HHmmss"
Export-RDDeploymentConfiguration -ConnectionBroker "rdscb.contoso.com" `
    -Path "C:\Backup\RDS-Config-$date.xml"
```

### Vérifier les événements après décommissionnement

```powershell
Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" `
    -MaxEvents 50 |
    Where-Object {$_.TimeCreated -gt (Get-Date).AddHours(-2)} |
    Format-List TimeCreated, Message
```

## Foire Aux Questions (FAQ)

**Q: Puis-je exécuter ce script depuis mon poste de travail ?**
R: Oui, si vous avez les outils RSAT installés et les droits appropriés.

**Q: Que se passe-t-il si le script échoue en cours d'exécution ?**
R: Le script s'arrête et génère un message d'erreur dans le log. Vous pouvez consulter le log pour diagnostiquer le problème.

**Q: Faut-il redémarrer le serveur après décommissionnement ?**
R: Seulement si vous utilisez le paramètre `-RemoveRole`. Dans ce cas, le script propose de redémarrer automatiquement.

**Q: Combien de temps prend le décommissionnement ?**
R: Cela dépend du nombre de sessions actives. Entre 5 minutes (aucune session) et 30+ minutes (avec attente de déconnexion).

**Q: Le script peut-il être automatisé ?**
R: Oui, mais il est recommandé d'utiliser les paramètres `-ForceLogoff` et `-Confirm:$false` pour une automatisation complète.

**Q: Que faire si un serveur est déjà en mode drain ?**
R: Le script détectera l'état actuel et continuera le processus de décommissionnement normalement.

## Support et contribution

Pour signaler un bug ou proposer une amélioration, créez une issue sur le repository GitHub.

## Licence

Ce script est fourni "tel quel" sans garantie. Testez toujours dans un environnement de non-production d'abord.

## Auteur

**Captain-Adam** - Étudiant en IT à Rennes, France 🇫🇷
Spécialisation : Infrastructure, Virtualisation, DevOps

---

**Version** : 1.0
**Dernière mise à jour** : Janvier 2026
