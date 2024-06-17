#!/bin/bash

# Vérifier si l'utilisateur courant est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Parcourir tous les répertoires utilisateur sous /home
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")

        # Vérifier si l'utilisateur a un dossier .ssh dans son répertoire personnel
        if [ -d "$user_home/.ssh" ]; then
            authorized_keys_file="$user_home/.ssh/authorized_keys"

            # Vérifier si le fichier authorized_keys existe déjà
            if [ -f "$authorized_keys_file" ]; then
                echo -e "\e[91mLe fichier $authorized_keys_file existe déjà pour l'utilisateur $username. Ignorer.\e[0m"
            else
                # Créer un fichier authorized_keys vide
                touch "$authorized_keys_file"
                chmod 600 "$authorized_keys_file"
                chown "$username:$username" "$authorized_keys_file"
                echo -e "\e[92mFichier $authorized_keys_file créé pour l'utilisateur $username.\e[0m"
            fi
        else
            # Si le dossier .ssh n'existe pas, le créer
            mkdir -p "$user_home/.ssh"
            chmod 700 "$user_home/.ssh"
            chown "$username:$username" "$user_home/.ssh"

            # Créer un fichier authorized_keys vide
            authorized_keys_file="$user_home/.ssh/authorized_keys"
            touch "$authorized_keys_file"
            chmod 600 "$authorized_keys_file"
            chown "$username:$username" "$authorized_keys_file"
            echo -e "\e[92mFichier $authorized_keys_file créé pour l'utilisateur $username.\e[0m"
        fi
    fi
done

echo -e "\e[94m********* FIN DU SCRIPT *********\e[0m"
sleep 1

# Commandes standards :
#
# mkdir /home/USER/.ssh
# chmod 700 /home/USER/.ssh/
# touch /home/USER/.ssh/authorized_keys
# chmod 600 /home/USER/.ssh/authorized_keys
# sudo chown -hR USER:USER /home/USER/.ssh/
#
