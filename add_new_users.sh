# 

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
            echo -e "\e[92mUtilisateur $username ajouté au groupe sudo.\e[0m"
        else
            echo "Utilisateur $username est déjà dans le groupe sudo. Ignorer l'ajout."
        fi
    fi
done

# Fonction pour vérifier si un utilisateur est dans le groupe sudo
user_in_sudo_group() {
    id -nG "$1" | grep -qw "sudo"
}

read -p "Y a-t-il des nouveaux comptes à créer ? (oui/non) " response

if [[ "$response" == "oui" ]]; then
    while true; do
        read -p "Entrez le nom du nouvel utilisateur : " new_username
        if id "$new_username" &>/dev/null; then
            echo -e "\e[91mL'utilisateur $new_username existe déjà. Veuillez choisir un autre nom.\e[0m"
            continue
        fi

        while true; do
            read -s -p "Entrez le mot de passe pour $new_username : " new_password
            echo
            read -s -p "Confirmez le mot de passe pour $new_username : " confirm_password
            echo
            if [[ "$new_password" == "$confirm_password" ]]; then
                break
            else
                echo -e "\e[91mLes mots de passe ne correspondent pas. Veuillez réessayer.\e[0m"
            fi
        done

        useradd -m -s /bin/bash "$new_username"
        echo "$new_username:$new_password" | chpasswd
        echo "Utilisateur $new_username créé avec le mot de passe fourni."

        if ! user_in_sudo_group "$new_username"; then
            usermod -aG sudo "$new_username"
            echo -e "\e[92mUtilisateur $new_username ajouté au groupe sudo.\e[0m"
        else
            echo -e "\e[93mUtilisateur $new_username est déjà dans le groupe sudo. Ignorer l'ajout.\e[0m"
        fi

        read -p "Souhaitez-vous créer un autre compte ? (oui/non) " another_response
        if [[ "$another_response" != "oui" ]]; then
            break
        fi
    done
else
    echo "Aucun nouveau compte ne sera créé."
fi
sleep 2

# Parcourir tous les répertoires utilisateur sous /home
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")

        # Vérifie si l'utilisateur n'est pas root et n'est pas un utilisateur système
        if [ "$username" != "root" ] && id -u "$username" >/dev/null 2>&1 && [ "$(id -u "$username")" -ge 1000 ]; then
            # Modifier le shell de l'utilisateur à "/usr/bin/bash"
            usermod -s /usr/bin/bash "$username"
            echo "Le shell de l'utilisateur $username a été modifié en /usr/bin/bash"
        fi

        ssh_dir="$user_home/.ssh"
        authorized_keys_file="$ssh_dir/authorized_keys"

        # Créer le dossier .ssh s'il n'existe pas, avec les permissions appropriées
        if [ ! -d "$ssh_dir" ]; then
            mkdir -p "$ssh_dir"
            chmod 700 "$ssh_dir"
            chown "$username:$username" "$ssh_dir"
        fi

        # Créer le fichier authorized_keys s'il n'existe pas, avec les permissions appropriées
        if [ ! -f "$authorized_keys_file" ]; then
            touch "$authorized_keys_file"
            chmod 600 "$authorized_keys_file"
            chown "$username:$username" "$authorized_keys_file"
            echo -e "\e[92mFichier $authorized_keys_file créé pour l'utilisateur $username.\e[0m"
        else
            echo "Le fichier $authorized_keys_file existe déjà pour l'utilisateur $username. Ignorer."
        fi
    fi
done
