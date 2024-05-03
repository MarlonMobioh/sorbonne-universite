#!/bin/bash

##########################################################################################
#                                      PREPROD PRIV
# Ce script modifie les parametres suivants sur un serveur lors d'une installation DEBIAN 11 et DEBIAN 12 :
#
# - Hostname
# - Adressage IP [interface ens192]
# - Création de l'ensemble des utilisateurs PEI ESI + esiansible
# - Création des dossiers et du fichier authorized_keys des utilisateurs PEI ESI
# - Configuration du fichier snmpd
# - Mise a jour des paquets [apt update]
# - Modification du /root/.bashrc
# - Vérifier que tous les services critiques sont en cours d’exécution
#
# - PROXY A CONFIGURER
#
##########################################################################################

# Vérifier si l'utilisateur courant est root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Demande à l'utilisateur de saisir le nouveau nom de la machine
echo "Quel est le nouveau nom complet de la machine ?"
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
allow-hotplug ens192
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

# Ajouter la configuration de firewall (PREPROD PRIV)
firewall_config='<?xml version="1.0" encoding="utf-8"?>
<zone>
  <short>Work</short>
  <description>For use in work areas. You mostly trust the other computers on networks to not harm your computer. Only selected incoming connections are accepted.</description>
  <service name="ssh"/>
  <service name="cockpit"/>
  <source address="172.22.0.0/24"/>
  <source address="10.50.0.0/18"/>
  <source address="134.157.254.117"/>
  <source address="134.157.33.239"/>
  <source address="134.157.134.0/24"/>
  <source address="134.157.142.0/24"/>
  <source address="134.157.143.0/24"/>
  <source address="134.157.33.0/24"/>
  <source address="134.157.1.240/23"/>
  <source address="10.11.16.0/22"/>
  <source address="10.11.19.239"/>
  <forward/>
</zone>'

echo "$firewall_config" > /etc/firewalld/zones/work.xml
echo "Configuration de firewall ajoutée dans work.xml."

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

#Update des paquets
apt update -y
apt upgrade -y
apt install -y inxi
#Installation postfix (stoppé et desactivé)
apt install -y postfix
systemctl stop postfix
systemctl disable postfix
apt install -y mailutils
apt install -y shellcheck
apt install -y htop
apt install -y net-tool
apt install -y psmisc
apt install -y mailx
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
apt install -y rsync 
apt install -y lsof
apt install -y vim
apt install -y nmap


# Modification du /root/.bashrc

CONTENTBASHRCADD="# ------------------------
# Configuration du prompt
# ------------------------
# Prompt colors
C_RED=\"\\[\\e[1;31m\\]\"
C_GREEN=\"\\[\\e[1;32m\\]\"
C_YELLOW=\"\\[\\e[1;33m\\]\"
C_BLUE=\"\\[\\e[1;34m\\]\"
C_MAGENTA=\"\\[\\e[1;35m\\]\"
C_CYAN=\"\\[\\e[1;36m\\]\"
C_WHITE=\"\\[\\e[1;37m\\]\"
C_DEF=\"\\[\\033[0m\\]\"

# Mode root
export PS1=\"\${C_RED}\\u@\\h:\${C_RED}\\w\${C_DEF} \${C_BLUE}#\${C_DEF} \"

# Aliases
alias vi='/usr/bin/vim \$*'
alias ll='ls $LS_OPTIONS -la'

# Affichage des zones
alias zones='firewall-cmd  --list-all-zones |egrep -A50 \"external|dmz|home|public|work|internal|trusted\" --group-separator=\"-------------\"'
alias zones1='firewall-cmd  --list-all-zones|less'
alias services='systemctl list-unit-files --type=service --state=enabled'"

# Ajouter le contenu CONTENTBASHRCADD à la fin du fichier .bashrc
echo "$CONTENTBASHRCADD" >> /root/.bashrc

echo "Contenu ajouté avec succès à /root/.bashrc."

source /root/.bashrc
#systemctl restart logrotate.service

# Vérifier que tous les services critiques sont en cours d’exécution
sudo systemctl list-units --type=service


# Message de fin de script
echo "Fin du script."

reboot
