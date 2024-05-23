#!/bin/bash

##########################################################################################
#                                        PREPROD
# Ce script modifie les parametres suivants sur un serveur lors d'une installation DEBIAN 11 et DEBIAN 12 :
#
# - Hostname
# - Adressage IP [interface ens192]
# - Création de l'ensemble des utilisateurs PEI ESI + esiansible
# - Création des dossiers et du fichier authorized_keys des utilisateurs PEI ESI
# - Configuration du fichier snmpd
# - Configuration du serveur de temps "timedatectl"
# - Mise a jour des paquets [apt update]
# - Modification du /root/.bashrc
# - Vérifier que tous les services critiques sont en cours d’exécution
#
##########################################################################################

# Vérifier si l'utilisateur courant est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Demande à l'utilisateur de saisir le nouveau nom de la machine
echo "Quel est le nouveau nom complet de la machine ? (format = server1.dev.dsi.priv.sorbonne-universite.fr)"
read new_hostname

# Modification du nom d'hôte
echo "$new_hostname" | sudo tee /etc/hostname > /dev/null
sudo hostnamectl set-hostname "$new_hostname"

# Redémarrer le service systemd-hostnamed pour appliquer les modifications
sudo systemctl restart systemd-hostnamed

echo "Le nom de la machine a été modifié avec succès en : $new_hostname"

# Demander à l'utilisateur l'adresse IP, le masque de sous-réseau et la passerelle
read -p "Entrez l'adresse IP : " ip_address
read -p "Entrez le masque de sous-réseau : " subnet_mask
read -p "Entrez la passerelle par défaut : " gateway

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

echo "Adresse IP changée avec succès. Nouvelles valeurs :"
ip addr show ens192 | grep -w inet

# Déterminer l'adresse IP de la machine
machine_ip=$(hostname -I | awk '{print $1}')

# Nom d'hôte à associer
machine_hostname=$(hostname)

# Vérifier si l'adresse IP et le nom d'hôte sont définis dans /etc/hosts
if [[ -z "$machine_ip" || -z "$machine_hostname" ]]; then
    echo "Impossible de récupérer l'adresse IP ou le nom d'hôte. Arrêt du script."
    exit 1
fi

# Ajouter une entrée dans /etc/hosts
sudo bash -c "echo '$machine_ip $machine_hostname' >> /etc/hosts"

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

# Parcours des utilisateurs dans /home
for user_home in /home/*/; do
    username=$(basename "$user_home")
    
    # Vérifie si l'utilisateur n'est pas root
    if [ "$username" != "root" ]; then
        # Modifier le shell de l'utilisateur à "/usr/bin/bash"
        usermod -s /usr/bin/bash "$username"
        echo "Le shell de l'utilisateur $username a été modifié en /usr/bin/bash"
    fi
done

# Parcourir tous les répertoires utilisateur sous /home
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        username=$(basename "$user_home")

        # Vérifier si l'utilisateur a un dossier .ssh dans son répertoire personnel
        if [ -d "$user_home/.ssh" ]; then
            authorized_keys_file="$user_home/.ssh/authorized_keys"

            # Vérifier si le fichier authorized_keys existe déjà
            if [ -f "$authorized_keys_file" ]; then
                echo "Le fichier $authorized_keys_file existe déjà pour l'utilisateur $username. Ignorer."
            else
                # Créer un fichier authorized_keys vide
                touch "$authorized_keys_file"
                chmod 600 "$authorized_keys_file"
                chown "$username:$username" "$authorized_keys_file"
                echo "Fichier $authorized_keys_file créé pour l'utilisateur $username."
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
            echo "Fichier $authorized_keys_file créé pour l'utilisateur $username."
        fi
    fi
done

# Ajouter la configuration de firewall (PREPROD)
firewall_config='<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Work</short>
  <description>For use in work areas. You mostly trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
  <service name="ssh"/>
  <service name="http"/>
  <service name="https"/>
  <service name="cockpit"/>
  <source address="172.22.0.0/24"/>
  <source address="10.50.0.0/18"/>
  <source address="134.157.143.0/24"/>
  <source address="134.157.142.0/24"/>
  <source address="134.157.126.0/23"/>
  <source address="134.157.150.0/24"/>
  <source address="134.157.164.0/23"/>
  <source address="134.157.134.0/24"/>
  <source address="134.157.33.0/24"/>
  <source address="134.157.1.128/25"/>
  <source address="134.157.254.117"/>
  <source address="134.157.254.8"/>
  <forward/>
</zone>'

echo "$firewall_config" > /etc/firewalld/zones/work.xml
echo "Configuration de firewall ajoutée dans work.xml."

# Ouvrir les ports web sur le pare-feu local
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --zone=work --add-port=443/tcp --permanent
firewall-cmd --zone=work --add-port=80/tcp --permanent

# Ouvrir le port EON (supervision)
firewall-cmd --permanent --zone=work --add-port=161/udp

# Redémarrer le service firewalld pour appliquer les modifications
systemctl restart firewalld
echo "Le service firewalld a été redémarré."

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
cat /etc/snmp/snmpd.conf

# Redémarrer le service SNMP
sudo systemctl restart snmpd

# Afficher le statut du service SNMP
sudo systemctl status snmpd

# Récupérer l'adresse IP de la passerelle à partir de la variable existante
gateway_address="$gateway"

# Modifier le fichier /etc/systemd/timesyncd.conf avec l'adresse IP de la passerelle
sudo sed -i "s/^NTP=.*/NTP=$gateway_address/" /etc/systemd/timesyncd.conf

# Redémarrer le service systemd-timesyncd pour appliquer les modifications
sudo systemctl restart systemd-timesyncd

echo "Le serveur de temps a été configuré avec succès avec l'adresse IP de la passerelle : $gateway_address"

# Update des paquets
apt-get update && apt-get -y upgrade && apt autoremove -y && apt-get clean -y

# Retirer X11 pour améliorer les performances et la sécurité
apt-get purge -y x11-common libwayland-server0

# Installation des paquets utiles
apt install -y inxi
#Installation postfix (stoppé et desactivé)
apt install -y postfix
systemctl stop postfix
systemctl disable postfix
apt install -y shellcheck
apt install -y net-tools
apt install -y psmisc
apt install -y mailx
apt install -y mailutils
apt install -y sasl2-bin
apt install -y rsyslog
apt install -y openssh-client
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

CONTENTBASHRCADD='# ~/.bashrc: executed by bash(1) for non-login shells.

# Note: PS1 and umask are already set in /etc/profile. You should not
# need this unless you want different defaults for root.
# PS1='${debian_chroot:+($debian_chroot)}\h:\w\$ '
# umask 022

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

export PATH="/snap/bin/:\$PATH"
'

# Ajouter le contenu CONTENTBASHRCADD à la fin du fichier .bashrc
echo "$CONTENTBASHRCADD" >> /root/.bashrc
echo "Contenu ajouté avec succès à /root/.bashrc."

# Charger les modifications du .bashrc
source /root/.bashrc

# Vérifier que tous les services critiques sont en cours d’exécution
sudo systemctl list-units --type=service

# Régénérer les clef SSH du host
rm -f /etc/ssh/ssh_host_* && dpkg-reconfigure openssh-server && \
/etc/init.d/ssh restart

# Vidage du contenu des fichiers de journalisation système
echo "" > /var/log/wtmp
echo "" > /var/log/lastlog

# Suppression history
history -c

# Message de fin de script
echo "Fin du script."

reboot
