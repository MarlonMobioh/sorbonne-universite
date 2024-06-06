#!/bin/bash

##########################################################################################
#                                        DEV
# Ce script modifie les parametres suivants sur un serveur lors d'une installation Red Hat 9 :
#
# - Hostname
# - Adressage IP [interface ens33]
# - Création de l'ensemble des utilisateurs PEI ESI + esiansible
# - Création des dossiers et du fichier authorized_keys des utilisateurs PEI ESI
# - Ajout de la configuration du firewall (DEV)
# - Configuration du fichier snmpd
# - Configuration du serveur de temps "timedatectl"
# - Mise à jour des paquets [dnf update]
# - Modification du /root/.bashrc
# - Vérifier que tous les services critiques sont en cours d’exécution
# - Suppression history / Suppression lastlog
# - Redémarrage du serveur
#
##########################################################################################

# Vérifier si l'utilisateur courant est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Demande à l'utilisateur de saisir le nouveau nom de la machine
echo -e "\e[91mQuel est le nouveau nom complet de la machine ? (format = server1.dev.dsi.priv.sorbonne-universite.fr)\e[0m"
read new_hostname

# Demander à l'utilisateur l'adresse IP, le masque de sous-réseau et la passerelle
echo -e "\e[91mEntrez l'adresse IP : \e[0m"
read ip_address
echo -e "\e[91mEntrez le masque de sous-réseau : \e[0m"
read subnet_mask
echo -e "\e[91mEntrez la passerelle par défaut : \e[0m"
read gateway

# Modifier le fichier de configuration réseau avec les nouvelles valeurs
nmcli con mod ens192 ipv4.addresses "$ip_address/$subnet_mask" ipv4.gateway "$gateway" ipv4.dns "134.157.0.129,134.157.192.1" ipv4.method manual

# Redémarrer le service réseau pour appliquer les modifications
nmcli con up ens192

# Modification du nom d'hôte
hostnamectl set-hostname "$new_hostname"
echo -e "\e[92mLe nom de la machine a été modifié avec succès en : $new_hostname\e[0m"
sleep 3

echo -e "\e[92mAdresse IP changée avec succès. Nouvelles valeurs : \e[0m"
ip addr show ens192 | grep -w inet
sleep 3

# Déterminer l'adresse IP de la machine
machine_ip=$(hostname -I | awk '{print $1}')
# Nom d'hôte à associer
machine_hostname=$(hostname)

# Vérifier que l'adresse IP et le nom d'hôte sont correctement définis dans /etc/hosts
if ! grep -q "$machine_ip\s*$machine_hostname" /etc/hosts; then
    echo "L'adresse IP et/ou le nom d'hôte ne sont pas correctement définis dans /etc/hosts."
    echo "Ajout des entrées dans /etc/hosts..."
    echo "$machine_ip $machine_hostname" >> /etc/hosts
    echo -e "\e[92mLes entrées ont été ajoutées à /etc/hosts.\e[0m"
    sleep 3
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

# Fonction pour vérifier l'appartenance d'un utilisateur au groupe wheel (équivalent sudo sur Red Hat)
user_in_wheel_group() {
    local username="$1"
    groups "$username" | grep -q "\bwheel\b"
}

# Ajouter les utilisateurs et leurs mots de passe
for user_pass in "${user_passwords[@]}"; do
    username=$(echo "$user_pass" | cut -d':' -f1)
    password=$(echo "$user_pass" | cut -d':' -f2)

    if id "$username" &>/dev/null; then
        echo "L'utilisateur $username existe déjà. Ignorer la création."
    else
        useradd -m -s /bin/bash "$username"
        echo "$username:$password" | chpasswd
        echo "Utilisateur $username créé avec le mot de passe $password."

        if ! user_in_wheel_group "$username"; then
            usermod -aG wheel "$username"
            echo -e "\e[92mUtilisateur $username ajouté au groupe wheel.\e[0m"
        else
            echo "Utilisateur $username est déjà dans le groupe wheel. Ignorer l'ajout."
        fi
    fi
done

# Parcourir tous les répertoires utilisateur sous /home
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")

        # Vérifie si l'utilisateur n'est pas root et n'est pas un utilisateur système
        if [ "$username" != "root" ] && id -u "$username" >/dev/null 2>&1 && [ "$(id -u "$username")" -ge 1000 ]; then
            # Modifier le shell de l'utilisateur à "/bin/bash"
            usermod -s /bin/bash "$username"
            echo "Le shell de l'utilisateur $username a été modifié en /bin/bash"
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

# Ajouter la configuration de firewall (DEV)
# Ajouter les services et ports nécessaires à la zone work, internal
echo -e "\e[94mAjout des services et ports nécessaires Sorbonne Université :\e[0m"
sleep 2

firewall-cmd --zone=work --add-service=ssh --permanent
firewall-cmd --zone=work --add-service=http --permanent
firewall-cmd --zone=work --add-service=https --permanent
firewall-cmd --zone=work --add-service=cockpit --permanent
firewall-cmd --zone=internal --add-port=161/udp --permanent
firewall-cmd --zone=internal --add-source=134.157.254.117 --permanent
firewall-cmd --zone=work --add-source=172.22.0.0/24 --permanent
firewall-cmd --zone=work --add-source=10.50.0.0/18 --permanent
firewall-cmd --zone=work --add-source=134.157.134.0/24 --permanent
firewall-cmd --zone=work --add-source=10.11.20.0/22 --permanent
firewall-cmd --zone=work --add-source=134.157.142.0/24 --permanent
firewall-cmd --zone=work --add-source=134.157.1.240/23 --permanent
firewall-cmd --zone=work --add-source=134.157.143.0/24 --permanent
firewall-cmd --zone=work --add-source=10.11.7.239 --permanent
firewall-cmd --zone=work --add-source=134.157.23.239 --permanent
firewall-cmd --zone=work --add-source=134.157.254.8 --permanent
firewall-cmd --zone=work --add-source=134.157.254.117 --permanent

# Redémarrer le service firewalld pour appliquer les modifications + afficher le statut du service firewalld
firewall-cmd --reload
systemctl restart firewalld
echo -e "\e[92******\e[92mLe service firewalld a été redémarré.******\e[0m"
systemctl status firewalld
sleep 3

# Création du compte esiansible SU
echo -e "\e[94mAjout du compte esiansible Sorbonne Université :\e[0m"
wget https://gitlab.dsi.upmc.fr/su-esi/esi-ansible/-/raw/main/templates/esiuser/user.sh
bash user.sh
echo -e "\e[92mL'utilisateur esiansible a été ajouté.\e[0m"

# Ajout du script snmpd
echo -e "\e[94mAjout de la configuration SNMP SU :\e[0m"
wget https://gitlab.dsi.upmc.fr/su-esi/esi-ansible/-/raw/main/templates/snmpd/snmpd.conf -O /etc/snmp/snmpd.conf
systemctl restart snmpd
systemctl enable snmpd
echo -e "\e[92mLa configuration SNMP a été mise à jour.\e[0m"

# Configuration serveur de temps "timedatectl"
echo -e "\e[94mConfiguration du serveur de temps :\e[0m"
timedatectl set-timezone Europe/Paris
timedatectl set-ntp true
echo -e "\e[92mLa configuration du serveur de temps a été mise à jour.\e[0m"
timedatectl status
sleep 3

# Mise à jour des paquets [dnf update]
echo -e "\e[94mMise à jour des paquets du serveur :\e[0m"
dnf update -y
echo -e "\e[92mLa mise à jour des paquets est terminée.\e[0m"
sleep 3

# Ajout du proxy HTTP pour l'utilisateur root
echo -e "\e[94mAjout de la configuration du proxy HTTP pour l'utilisateur root :\e[0m"
cat <<EOF >> /root/.bashrc

# Configuration du proxy HTTP
export http_proxy="http://194.199.16.3:3128"
export https_proxy="http://194.199.16.3:3128"
export no_proxy="localhost,127.0.0.1,.local"
EOF
echo -e "\e[92mLa configuration du proxy HTTP a été ajoutée à /root/.bashrc.\e[0m"

# Vérification des services critiques
echo -e "\e[94mVérification des services critiques :\e[0m"
for service in sshd network firewalld snmpd; do
    systemctl is-active --quiet "$service" && echo -e "\e[92mLe service $service est actif.\e[0m" || echo -e "\e[91mLe service $service n'est pas actif.\e[0m"
done
sleep 3

# Suppression history / Suppression lastlog
echo -e "\e[94mSuppression de l'historique des commandes et des logs :\e[0m"
history -c
> ~/.bash_history
truncate -s 0 /var/log/lastlog
echo -e "\e[92mL'historique des commandes et les logs ont été supprimés.\e[0m"

# Redémarrage du serveur
echo -e "\e[94mRedémarrage du serveur...\e[0m"
sleep 3
reboot
