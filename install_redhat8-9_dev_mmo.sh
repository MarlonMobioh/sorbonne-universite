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
# - Renseignement dans fichier de log mmo.log
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
echo -e "\e[91mEntrez le masque de sous-réseau (ex: 22 pour 255.255.252.0) : \e[0m"
read subnet_mask
echo -e "\e[91mEntrez la passerelle par défaut : \e[0m"
read gateway

# Déterminer le nom de l'interface (remplacez "ens33" par le nom réel de votre interface si différent)
interface="ens33"

# Modifier la connexion avec nmcli
sudo nmcli connection modify $interface ipv4.addresses "${ip_address}/${subnet_mask}"
sudo nmcli connection modify $interface ipv4.gateway "${gateway}"
sudo nmcli connection modify $interface ipv4.method manual
sudo nmcli connection modify $interface ipv4.dns "134.157.0.129 134.157.192.1"

# Redémarrer l'interface réseau pour appliquer les modifications
sudo nmcli connection down $interface && sudo nmcli connection up $interface

# Afficher les nouvelles valeurs
echo -e "\e[92mAdresse IP changée avec succès. Nouvelles valeurs : \e[0m"
ip addr show $interface | grep -w inet
sleep 3

# Modification du nom d'hôte
hostnamectl set-hostname "$new_hostname"
echo -e "\e[92mLe nom de la machine a été modifié avec succès en : $new_hostname\e[0m"
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
firewall-cmd --zone=work --add-source=134.157.142.0/24 --permanent
firewall-cmd --zone=work --add-source=134.157.1.240/23 --permanent
firewall-cmd --zone=work --add-source=134.157.143.0/24 --permanent
firewall-cmd --zone=work --add-source=10.11.7.239 --permanent
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
wget https://gitlab.dsi.sorbonne-universite.fr/cherigui/dsi-public/-/raw/main/mise_en_conformite_esiansible.sh
bash mise_en_conformite_esiansible.sh
echo -e "\e[92mL'utilisateur esiansible a été ajouté.\e[0m"
sleep 2

# Installation des paquets necessaires SNMP
dnf install -y net-snmp net-snmp-libs net-snmp-utils
dnf update -y net-snmp net-snmp-libs net-snmp-utils
systemctl restart snmpd
systemctl enable snmpd
#echo -e "\e[92mLa configuration SNMP a été mise à jour.\e[0m"

# Configuration de chronyd
echo -e "\e[94mConfiguration du serveur de temps :\e[0m"
# Sauvegarder le fichier de configuration original de chrony
cp /etc/chrony.conf /etc/chrony.conf.old
# Modifier /etc/chrony.conf pour utiliser la passerelle comme serveur NTP
sed -i "s/^pool /#pool /" /etc/chrony.conf
echo "server 134.157.254.19 iburst" >> /etc/chrony.conf
# Redémarrer le service chronyd pour appliquer les modifications
systemctl restart chronyd
# Vérifier le statut du service chronyd
systemctl status chronyd
echo -e "\e[92m*** Le service chronyd a été redémarré.***\e[0m"
echo "*** Waiting 5 sec ... ***"
sleep 5
# Vérifier la synchronisation de l'horloge
timedatectl
sleep 3
echo "\e[92mConfiguration de chronyd avec l'adresse IP 134.157.254.19 (ntp1.jussieu.fr) effectuée.\e[0m"

# Enregistrement dans RedHat (mmobioh ; Sorbonne@2023)
echo -e "\e[94mEnregistrement dans RedHat :\e[0m"
echo "Nettoyage des informations d'inscription précédentes"
subscription-manager clean
echo "Enregistrement de l'utilisateur [mmobioh]"
subscription-manager register --username=mmobioh --password=Sorbonne@2023
#echo "Affichage de la liste des abonnements disponibles"
#subscription-manager list --available
echo "Attachement de l'abonnement spécifique identifié par le code de pool 8a85f99977b0c0420177f2a086211111s"
subscription-manager attach --pool=8a85f99977b0c0420177f2a086211111
echo "\e[92m *** Abonnement Redhat 8a85f99977b0c0420177f2a086211111 attaché *** \e[0m"
sleep 3

# Mise à jour des paquets [dnf update]
echo -e "\e[94mMise à jour des paquets du serveur :\e[0m"
dnf update -y
dnf upgrade -y
dnf autoremove -y
dnf clean all -y
# Installation des paquets utiles
dnf install -y inxi
# Installation postfix (stoppé et désactivé)
dnf install -y postfix
systemctl stop postfix
systemctl disable postfix
dnf install -y shellcheck
dnf install -y fail2ban
dnf install -y net-tools
dnf install -y psmisc
dnf install -y mailx mailutils s-nail
dnf install -y cyrus-sasl
dnf install -y rsyslog
dnf install -y openssh-clients
dnf install -y dstat
dnf install -y iotop 
dnf install -y lnav
dnf install -y mlocate
dnf install -y bind-utils 
dnf install -y traceroute
dnf install -y lsof htop telnet unzip whois vim wget man tree gcc
dnf install -y ccze mc tmux rsync
echo -e "\e[92mLa mise à jour des paquets est terminée.\e[0m"
sleep 3

# Modification du /root/.bashrc
cat <<'EOF' > /root/.bashrc
# ------------------------
# Configuration du prompt
# ------------------------
# Prompt colors
C_RED="\[\e[1;31m\]"
C_GREEN="\[\e[1;32m\]"
C_YELLOW="\[\e[1;33m\]"
C_BLUE="\[\e[1;34m\]"
C_MAGENTA="\[\e[1;35m\]"
C_CYAN="\[\e[1;36m\]"
C_WHITE="\[\e[1;37m\]"
C_DEF="\[\033[0m\]"

# Mode root
export PS1="${C_RED}\u@\h:${C_RED}\w${C_DEF} ${C_BLUE}#${C_DEF} "

# Affichage des zones
alias zones="firewall-cmd --list-all-zones | egrep -A50 \"external|dmz|home|public|work|internal|trusted\" --group-separator=\"-------------\""
alias zones1="firewall-cmd --list-all-zones | less"
alias services="systemctl list-unit-files --type=service --state=enabled"

# You may uncomment the following lines if you want ls to be colorized:
# export LS_OPTIONS="--color=auto"
# eval "$(dircolors)"
alias ls="ls \$LS_OPTIONS"
alias ll="ls \$LS_OPTIONS -la"
alias l="ls \$LS_OPTIONS -lA"
alias vi="/usr/bin/vim \$*"

# Some more aliases to avoid making mistakes:
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
alias last="last -F"

# Ajout de /snap/bin au PATH existant
export PATH="/snap/bin:$PATH"
EOF

echo "\e[92mContenu ajouté avec succès à /root/.bashrc.\e[0m"
# Sourcer .bashrc pour appliquer les modifications au shell actuel
source /root/.bashrc

# Vérification des services critiques
echo -e "\e[94mVérification des services critiques :\e[0m"
# Vérifier que tous les services critiques sont en cours d’exécution
systemctl list-units --type=service

# Suppression history / Suppression lastlog
echo -e "\e[94mSuppression de l'historique des commandes et des logs :\e[0m"
# Vidage du contenu des fichiers de journalisation système
> /var/log/wtmp
> /var/log/lastlog
# Suppression history
history -c
echo -e "\e[92mL'historique des commandes et les logs ont été supprimés.\e[0m"

# Nom du script
script_name=$(basename "$0")
# Fichier de log
log_file="/var/log/mmo.log"
# Vérifier si le fichier de log est accessible en écriture
if [ ! -w "$log_file" ]; then
    echo "Erreur: le fichier de log $log_file n'est pas accessible en écriture."
    exit 1
fi
# Ajouter une entrée de log indiquant que le script a été exécuté
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Le script $script_name a été exécuté sur la machine : $(hostname) par l'utilisateur $(whoami)."
} >> "$log_file"
sleep 3

# Message de fin de script
echo "********** Fin du script **********"
sleep 2
# Redémarrage du serveur
echo -e "\e[94m****** Redémarrage du serveur... ******\e[0m"
sleep 3
reboot
