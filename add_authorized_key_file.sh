#!/bin/bash

# Vérifier si l'utilisateur courant est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Vérifier et créer le dossier .ssh et le fichier authorized_keys
    user_home="/home/$username"
    authorized_keys_file="$user_home/.ssh/authorized_keys"

    if [ ! -d "$user_home/.ssh" ]; then
        mkdir -p "$user_home/.ssh"
        chmod 700 "$user_home/.ssh"
        chown "$username:$username" "$user_home/.ssh"
    fi

    if [ ! -f "$authorized_keys_file" ]; then
        touch "$authorized_keys_file"
        chmod 600 "$authorized_keys_file"
        chown "$username:$username" "$authorized_keys_file"
        echo "Fichier $authorized_keys_file créé pour l'utilisateur $username."
    else
        echo "Le fichier $authorized_keys_file existe déjà pour l'utilisateur $username. Ignorer."
    fi
done
