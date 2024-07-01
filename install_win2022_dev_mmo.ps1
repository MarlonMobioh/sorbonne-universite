Write-Host "###########################################################################"
Write-Host "######################### RENOMMAGE DE MACHINE ##############################"
Write-Host "###########################################################################"

$nombreDeTentatives = 0
$nombreMaxTentatives = 3

function Validate-Hostname {
    param (
        [string]$Hostname
    )
    if ($Hostname -match '^[a-zA-Z0-9-]{1,63}$' -and $Hostname -notmatch '^-|-$') {
        return $true
    } else {
        return $false
    }
}

do {
    $Hostname = Read-Host "[Note1] Renseigner le nom du serveur : (Le nom d'ordinateur doit respecter certaines règles : il ne doit pas contenir d'espaces ou de points, il doit contenir des lettres, des chiffres ou des tirets, et ne peut pas être constitué entièrement de chiffres ou dépasser 63 caractères)."
    if (Validate-Hostname -Hostname $Hostname) {
        break
    } else {
        $nombreDeTentatives++
        if ($nombreDeTentatives -eq $nombreMaxTentatives) {
            Write-Host "Nombre maximum de tentatives atteint. Arrêt du script."
            pause
            exit
        } else {
            Write-Host "Nom de serveur incorrect. Tentative $($nombreDeTentatives) sur $($nombreMaxTentatives). Merci de relancer le script et respecter la règle de nommage (voir [Note1] en début de script)."
        }
    }
} while ($true)

# Définir la configuration réseau du serveur (désactivée pour l'instant)
#$ip = Read-Host "Quelle est l'adresse IP du serveur ?"
#$masquesousreseau = Read-Host "Quel est le masque sous-réseau du serveur ?"
#$passerelle = Read-Host "Quelle est la passerelle du serveur ?"

# Write-Host "Les informations ci-dessous ont été renseignées :"
# Write-Host "Nom du serveur : $Hostname"
# Write-Host "Adresse IP : $ip"
# Write-Host "Masque sous-réseau : $masquesousreseau"
# Write-Host "Passerelle : $passerelle"
pause

# Renommage du serveur
Rename-Computer -NewName $Hostname

# Reboot du serveur (+Confirmation)
Restart-Computer -Confirm

# Ajout compte utilisateurs Windows Server 2022 de dev
# net user mobioh /add Sorbonne@2023 /FULLNAME:"Marlon MOBIOH" /COMMENT:"Prestataire AVA6"

# Ajout membres administrateurs Windows Server 2022
# net localgroup administrateurs mobioh /add
# net localgroup "utilisateurs du bureau à distance" scrisu /add
