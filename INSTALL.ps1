#Définir le nom du serveur

Write-Host "###########################################################################"
Write-Host "######################### RENOMMAGE DE MACHINE ##############################"
Write-Host "###########################################################################"

$nombreDeTentatives = 0
$nombreMaxTentatives = 3

do {
    $Hostname = Read-Host "Renseigner le nom complet du serveur : (Le format de nommage  'd-')"
    if ($Hostname -like "d-*") {
        break
    } else {
        $nombreDeTentatives++
        if ($nombreDeTentatives -eq $nombreMaxTentatives) {
            Write-Host "Nombre maximum de tentatives atteint. Arrêt du script."
            pause
            exit
        } else {
            Write-Host "Nom de serveur incorrect. Tentative $($nombreDeTentatives) sur $($nombreMaxTentatives)."
        }
    }
} while ($true)
   
#Definir la configuration réseau du serveur
#$ip = Read-Host "Quelle est l'adresse IP du serveur ?"
#$masquesousreseau = Read-Host "Quel est le masque sous-réseau du serveur ?"
#$passerelle = Read-Host "Quelle est la passerelle du serveur ?"

#Write-Host "Les informations ci dessous ont été renseignées :"
#$Hostname
#$ip
#$masquesousreseau
#$passerelle
pause

#Renommage du serveur
Rename-Computer -NewName $Hostname

#Reboot du serveur (+Confirmation)
Restart-Computer -Confirm




#Ajout compte utilisateurs Windows Server 2022 de dev
#net user mobioh /add Sorbonne@2023 /FULLNAME:"Marlon MOBIOH" /COMMENT:"Prestataire AVA6"

#Ajout membres administrateurs Windows Server 2022
#net localgroup administrateurs mobioh /add
#net localgroup "utilisateurs du bureau à distance" scrisu /add
