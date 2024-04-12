# Marlon MOBIOH
# 12/04/2024
# Télécharger le fichier = wget -P /tmp  https://github.com/MarlonMobioh/sorbonne-universite/blob/a45fe26de8d5204fc20205da49a32905619728e4/install_debian12_dev_mmo.sh
# Executer le fichier git = bash install_debian12_dev_mmo.sh
# Voir en commentaire le détail de chaque commande

#!/bin/bash

# Vérifier si l'utilisateur courant est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Définition des utilisateurs dans un tableau avec leur mot de passe respectif
user_passwords=(
    "admin.ava6.mobioh:Sorbonne@2023"
    "mejdi:%toto;2010"
    "lechaffotec:lechaffotec123!"
    "morelle:gzr5^dwgPsirLg"
    "cherigui:123@@@-AZE"
    "fegard:@EoVqEL12378"
)

# Fonction pour vérifier l'appartenance d'un utilisateur au groupe sudo
user_in_sudo_group() {
    local username="$1"
    grep -q "^sudo:x:.*$username" /etc/group
}

# Ajouter les utilisateurs et leurs mots de passe
for user_pass in "${user_passwords[@]}"; do
    username=$(echo "$user_pass" | cut -d':' -f1)
    password=$(echo "$user_pass" | cut -d':' -f2)

    if id "$username" &>/dev/null; then
        echo "L'utilisateur $username existe déjà. Ignorer la création."
    else
        useradd -m -s /usr/bin/bash "$username"
        echo "$username:$password" | chpasswd
        echo "Utilisateur $username créé avec le mot de passe $password."

        if ! user_in_sudo_group "$username"; then
            usermod -aG sudo "$username"
            echo "Utilisateur $username ajouté au groupe sudo."
        else
            echo "Utilisateur $username est déjà dans le groupe sudo. Ignorer l'ajout."
        fi
    fi
done

# Ajouter la configuration de firewall
firewall_config='<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Work</short>
  <description>For use in work areas. You mostly trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
  <service name="ssh"/>
  <service name="http"/>
  <service name="https"/>
  <source address="172.22.0.0/24"/>
  <source address="10.50.0.0/18"/>
  <source address="134.157.134.0/24"/>
  <source address="10.11.20.0/22"/>
  <source address="134.157.142.0/23"/>
  <source address="134.157.1.240/23"/>
  <source address="134.157.143.0/24"/>
  <source address="10.11.7.239"/>
  <source address="134.157.23.239"/>
  <forward/>
</zone>'

echo "$firewall_config" > /etc/firewalld/zones/work.xml
echo "Configuration de firewall ajoutée dans work.xml."

# Redémarrer le service firewalld pour appliquer les modifications
systemctl restart firewalld
echo "Le service firewalld a été redémarré."

