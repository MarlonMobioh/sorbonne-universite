# TEST
#!/bin/bash

# Définition des utilisateurs dans un tableau avec leur mot de passe respectif
user_passwords=(
    "admin.ava6.mobioh:${ADMIN_PASSWORD_MMO}"
    "mejdi:${ADMIN_PASSWORD_MBO}"
    "lechaffotec:${ADMIN_PASSWORD_CLC}"
    "morelle:${ADMIN_PASSWORD_OMO}"
    "cherigui:${ADMIN_PASSWORD_MCH}"
    "fegard:${ADMIN_PASSWORD_FFE}"
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
