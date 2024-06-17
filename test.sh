# TEST
#!/bin/bash

# Définition des utilisateurs dans un tableau avec leur mot de passe respectif
user_passwords=(
    "admin.ava6.mobioh:${{ secrets.admin_password_mmo }}"
    "mejdi:${{ secrets.admin_password_mbo }}"
    "lechaffotec:${{ secrets.admin_password_clc }}"
    "morelle:${{ secrets.admin_password_omo }}"
    "cherigui:${{ secrets.admin_password_mch }}"
    "fegard:${{ secrets.admin_password_ffe }}"
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
            echo -e "\e[92mUtilisateur $username ajouté au groupe sudo.\e[0m"
        else
            echo "Utilisateur $username est déjà dans le groupe sudo. Ignorer l'ajout."
        fi
    fi
done
