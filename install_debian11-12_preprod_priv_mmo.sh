#!/bin/bash

##########################################################################################
#                                        PREPROD PRIV
# Ce script modifie les parametres suivants sur un serveur lors d'une installation DEBIAN 11 et DEBIAN 12 :
#
# - Hostname
# - Adressage IP [interface ens192]
# - Création de l'ensemble des utilisateurs PEI ESI + esiansible
# - Création des dossiers et du fichier authorized_keys des utilisateurs PEI ESI
# - Ajout de la configuration du firewall (PREPROD PRIV)
# - Configuration du fichier snmpd
# - Configuration du serveur de temps "timedatectl"
# - Mise a jour des paquets [apt update]
# - Modification du /root/.bashrc
# - Vérifier que tous les services critiques sont en cours d’exécution
# - Suppression history / Suppression lastlog
# - Redemarrage du serveur
#
##########################################################################################

# Vérifier si l'utilisateur courant est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Demande à l'utilisateur de saisir le nouveau nom de la machine
echo -e "\e[91mQuel est le nouveau nom complet de la machine ? (format = server1.qualif.dsi.priv.sorbonne-universite.fr)\e[0m"
read new_hostname

# Modification du nom d'hôte
echo "$new_hostname" | sudo tee /etc/hostname > /dev/null
hostnamectl set-hostname "$new_hostname"

# Redémarrer le service systemd-hostnamed pour appliquer les modifications
systemctl restart systemd-hostnamed
echo "Le nom de la machine a été modifié avec succès en : \e[92m$new_hostname\e[0m"
sleep 3

# Demander à l'utilisateur l'adresse IP, le masque de sous-réseau et la passerelle
echo -e "\e[91mEntrez l'adresse IP : \e[0m" 
read ip_address
echo -e "\e[91mEntrez le masque de sous-réseau : \e[0m"
read subnet_mask
echo -e "\e[91mEntrez la passerelle par défaut : \e[0m"
read gateway

# Modifier le fichier /etc/network/interfaces avec les nouvelles valeurs
echo "
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5). 

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto ens192
iface ens192 inet static
	address $ip_address
	netmask $subnet_mask
	gateway $gateway
        # dns-* options are implemented by the resolvconf package, if installed
        dns-nameservers 134.157.0.129 134.157.192.1
        dns-search sorbonne-universite.fr dsi.sorbonne-universite.fr
" > /etc/network/interfaces

# Redémarrer le service réseau pour appliquer les modifications
systemctl restart networking
#ifdown ens192
#ifup ens192
#ip link set ens192 up
sleep 3

echo "Adresse IP changée avec succès. Nouvelles valeurs :"
ip addr show ens192 | grep -w inet

# Demande à l'utilisateur de saisir l'adresse du proxy
echo -e "\e[91mQuel est l'adresse du proxy de la machine ? (format = http://10.11.XXX.XXX:3128/) \e[0m"
read new_proxy

# Configuration des paramètres du proxy
PROXY_URL="$new_proxy"
NO_PROXY="localhost,127.0.0.1,::1"

# Configurer les variables d'environnement pour le proxy de manière permanente
sudo sh -c "echo 'http_proxy=$PROXY_URL' >> /etc/environment"
sudo sh -c "echo 'https_proxy=$PROXY_URL' >> /etc/environment"
sudo sh -c "echo 'ftp_proxy=$PROXY_URL' >> /etc/environment"
sudo sh -c "echo 'no_proxy=$NO_PROXY' >> /etc/environment"

# Configurer le proxy pour APT de manière permanente
echo "Acquire::http::Proxy \"$PROXY_URL\";" | sudo tee /etc/apt/apt.conf.d/01proxy
echo "Acquire::https::Proxy \"$PROXY_URL\";" | sudo tee -a /etc/apt/apt.conf.d/01proxy
echo "Acquire::ftp::Proxy \"$PROXY_URL\";" | sudo tee -a /etc/apt/apt.conf.d/01proxy

# Vérification de la configuration du proxy
echo "Les variables d'environnement de proxy sont configurées comme suit :"
cat /etc/environment | grep -E 'http_proxy|https_proxy|ftp_proxy|no_proxy'

echo "Le fichier de configuration APT est configuré comme suit :"
cat /etc/apt/apt.conf.d/01proxy

# Déterminer l'adresse IP de la machine
machine_ip=$(hostname -I | awk '{print $1}')

# Nom d'hôte à associer
machine_hostname=$(hostname)

# Vérifier que l'adresse IP et le nom d'hôte sont correctement définis dans /etc/hosts
if ! grep -q "$machine_ip\s*$machine_hostname" /etc/hosts; then
    echo "L'adresse IP et/ou le nom d'hôte ne sont pas correctement définis dans /etc/hosts."
    echo "Ajout des entrées dans /etc/hosts..."
    echo "$machine_ip $machine_hostname" >> /etc/hosts
    echo "Les entrées ont été ajoutées à /etc/hosts."
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

#!/bin/bash

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
            echo "Fichier $authorized_keys_file créé pour l'utilisateur $username."
        else
            echo "Le fichier $authorized_keys_file existe déjà pour l'utilisateur $username. Ignorer."
        fi
    fi
done

# Ajouter la configuration de firewall (PREPROD PRIV)
#firewall_config='<?xml version="1.0" encoding="utf-8"?>
#<zone>
#  <short>Work</short>
#  <description>For use in work areas. You mostly trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
#  <service name="ssh"/>
#  <service name="http"/>
#  <service name="https"/>
#  <service name="cockpit"/>
#  <source address="172.22.0.0/24"/>
#  <source address="10.50.0.0/18"/>
#  <source address="134.157.134.0/24"/>
#  <source address="10.11.20.0/22"/>
#  <source address="134.157.142.0/24"/>
#  <source address="134.157.1.240/23"/>
#  <source address="134.157.143.0/24"/>
#  <source address="10.11.7.239"/>
#  <source address="134.157.23.239"/>
#  <source address="134.157.254.8"/>
#  <source address="134.157.254.117"/> 
#  <forward/>
#</zone>'

#echo "$firewall_config" > /etc/firewalld/zones/work.xml
#echo "Configuration de firewall ajoutée dans work.xml."

# Ajouter les services et ports nécessaires à la zone work + Ouvrir le port EON (supervision)
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
firewall-cmd --zone=work --add-source=134.157.143.0/24 --permanent
firewall-cmd --zone=work --add-source=134.157.126.0/23 --permanent
firewall-cmd --zone=work --add-source=134.157.164.0/23 --permanent
firewall-cmd --zone=work --add-source=134.157.150.0/24 --permanent
firewall-cmd --zone=work --add-source=134.157.1.240/23 --permanent
firewall-cmd --zone=work --add-source=10.11.19.239 --permanent
firewall-cmd --zone=work --add-source=134.157.254.8 --permanent

# Redémarrer le service firewalld pour appliquer les modifications + afficher le statut du service firewalld
firewall-cmd --reload
systemctl restart firewalld
systemctl status firewalld
echo "*** Le service firewalld a été redémarré.***"
sleep 3

#Création du compte esiansible SU
wget https://gitlab.dsi.sorbonne-universite.fr/cherigui/dsi-public/-/raw/main/mise_en_conformite_esiansible.sh
bash mise_en_conformite_esiansible.sh

# Récupérer l'adresse IP de l'interface ens192
ip=$(ip -4 addr show dev ens192 | grep inet | awk '{print $2}' | cut -d'/' -f1)
echo "Adresse IP récupérée : $ip"

# Mettre à jour le fichier de configuration SNMP
sudo sed -i "s/^agentaddress .*/agentaddress 127.0.0.1,\[::1\],udp:$ip:161/" /etc/snmp/snmpd.conf

# Afficher le contenu du fichier de configuration SNMP
echo "Contenu de /etc/snmp/snmpd.conf après la mise à jour :"
cat /etc/snmp/snmpd.conf | grep 161
sleep 3

# Redémarrer le service SNMP + afficher le statut du service SNMP
sudo systemctl restart snmpd
sudo systemctl status snmpd

# Lister les ports en écoute
ss -ulnp | grep 161
sleep 3

# Récupérer l'adresse IP de la passerelle à partir de la variable existante
ntp1="10.11.19.254"

# Modifier le fichier /etc/systemd/timesyncd.conf avec l'adresse IP de la passerelle
sudo sed -i "s/^NTP=.*/NTP=$ntp1/" /etc/systemd/timesyncd.conf
echo "Configuration de /etc/systemd/timesyncd.conf avec l'adresse IP $ntp1 (r-v944.reseau.jussieu.fr) effectuée."
cat /etc/systemd/timesyncd.conf | grep NTP

# Redémarrer le service systemd-timesyncd pour appliquer les modifications + afficher le statut du service systemd-timesyncd
systemctl restart systemd-timesyncd
systemctl status systemd-timesyncd
sleep 3

# Vérifier la synchronisation de l'horloge
timedatectl
sleep 3

# Update des paquets
apt-get update && apt-get -y upgrade && apt autoremove -y && apt-get clean -y

# Retirer X11 pour améliorer les performances et la sécurité
apt-get purge x11-common libwayland-server0

# Installation des paquets utiles
apt install -y inxi
#Installation postfix (stoppé et desactivé)
apt install -y postfix
systemctl stop postfix
systemctl disable postfix
apt install -y shellcheck
apt install -y fail2ban
apt install -y net-tools
apt install -y psmisc
apt install -y mailx
apt install -y mailutils s-nail
apt install -y sasl2-bin
apt install -y rsyslog
apt install -y openssh-clients
apt install -y wget
apt install -y htop
apt install -y dstat
apt install -y iotop 
apt install -y lnav
apt install -y mlocate
apt install -y man 
apt install -y mail 
apt install -y tree
apt install -y bind-utils 
apt install -y whois
apt install -y traceroute
apt install -y unzip
apt install -y telnet 
apt install -y lsof
apt install -y vim
apt install -y ccze mc tmux rsync htop net-tools dnsutils

# Modification du /root/.bashrc
# Default prompt en cas de problème :
# export PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

CONTENTBASHRCADD='# ------------------------
# Configuration du prompt | PEI-ESI (mmo,nsa)
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
alias zones="firewall-cmd  --list-all-zones |egrep -A50 \"external|dmz|home|public|work|internal|trusted\" --group-separator=\"-------------\""
alias zones1="firewall-cmd  --list-all-zones|less"
alias services="systemctl list-unit-files --type=service --state=enabled"

# You may uncomment the following lines if you want ls to be colorized:
# export LS_OPTIONS="--color=auto"
# eval "$(dircolors)"
alias ls="ls \$LS_OPTIONS"
alias ll="ls \$LS_OPTIONS -la"
alias l="ls \$LS_OPTIONS -lA"
alias vi="/usr/bin/vim \$*"

# Some more alias to avoid making mistakes:
alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"
alias last="last -F"

export PATH="/snap/bin:$PATH"
'

# Ajouter le contenu CONTENTBASHRCADD à la fin du fichier .bashrc
echo "$CONTENTBASHRCADD" > /root/.bashrc
echo "Contenu ajouté avec succès à /root/.bashrc."

# Charger les modifications du .bashrc
source /root/.bashrc

#systemctl restart logrotate.service

# Vérifier que tous les services critiques sont en cours d’exécution
systemctl list-units --type=service

# Régénérer les clef SSH du host
rm -f /etc/ssh/ssh_host_* && dpkg-reconfigure openssh-server && \
/etc/init.d/ssh restart

# Vidage du contenu des fichiers de journalisation système
> /var/log/wtmp
> /var/log/lastlog

# Suppression history
history -c

# Message de fin de script
echo "********** Fin du script **********"
sleep 2

echo "************************************************"
echo "********** Redémarrage du serveur ... **********"
echo "************************************************"
sleep 3
reboot
