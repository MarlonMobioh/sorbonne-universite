#!/bin/bash

##########################################################################################
#                                      DEV
# Ce script modifie les paramètres suivants sur un serveur lors d'une installation RHEL 9.3 :
#
# - Hostname
# - Adressage IP [interface ens33]
# - Création de l'ensemble des utilisateurs PEI ESI + esiansible
# - Création des dossiers/fichiers authorized_keys des utilisateurs PEI ESI
# - Configuration du fichier snmpd
# - Configuration du serveur de temps "timedatectl"
# - Mise a jour des paquets [dnf update]
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
read -p "Quel est le nouveau nom complet de la machine ? " new_hostname

# Modification du nom d'hôte
hostnamectl set-hostname "$new_hostname"
echo "Le nom de la machine a été modifié avec succès en : $new_hostname"

# Demander à l'utilisateur l'adresse IP, le masque de sous-réseau et la passerelle
read -p "Entrez l'adresse IP : " ip_address
read -p "Entrez le masque de sous-réseau : " subnet_mask
read -p "Entrez la passerelle par défaut : " gateway

# Modifier le fichier /etc/sysconfig/network-scripts/ifcfg-ens192 avec les nouvelles valeurs
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-ens33
TYPE=Ethernet
BOOTPROTO=none
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
NAME=ens33
DEVICE=ens33
ONBOOT=yes
IPADDR=$ip_address
NETMASK=$subnet_mask
GATEWAY=$gateway
DNS1=134.157.0.129
DNS2=134.157.192.1
EOF

# Redémarrer l'interface réseau pour appliquer les modifications
nmcli connection reload

echo "Adresse IP changée avec succès. Nouvelles valeurs :"
ip addr show ens33 | grep -w inet

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

# Boucle pour créer les utilisateurs et configurer les fichiers .ssh/authorized_keys
for user_info in "${user_passwords[@]}"; do
    # Extraire le nom d'utilisateur et le mot de passe du tableau
    username=$(echo "$user_info" | cut -d ":" -f 1)
    password=$(echo "$user_info" | cut -d ":" -f 2)

    # Vérifier si l'utilisateur existe déjà
    if id "$username" &>/dev/null; then
        echo "L'utilisateur $username existe déjà. Ignorer la création."
    else
        # Créer l'utilisateur avec le mot de passe spécifié
        useradd -m -s /bin/bash "$username"
        echo "$username:$password" | chpasswd

        # Ajouter l'utilisateur au groupe wheel s'il n'y est pas déjà
        if ! user_in_wheel_group "$username"; then
            usermod -aG wheel "$username"
            echo "Utilisateur $username ajouté au groupe wheel."
        else
            echo "Utilisateur $username est déjà dans le groupe wheel. Ignorer l'ajout."
        fi
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

# Création du compte esiansible SU
wget https://gitlab.dsi.sorbonne-universite.fr/cherigui/dsi-public/-/raw/main/mise_en_conformite_esiansible.sh
bash mise_en_conformite_esiansible.sh

# Récupérer l'adresse IP de l'interface ens33
ip=$(ip -4 addr show dev ens33 | grep inet | awk '{print $2}' | cut -d'/' -f1)
echo "Adresse IP récupérée : $ip"

# Mettre à jour le fichier de configuration SNMP
sed -i -e 's/^#\(com2sec notConfigUser  default       public\)/com2sec notConfigUser  '$ip'       public/' \
       -e 's/^#\(group   notConfigGroup v1           notConfigUser\)/\1/' \
       -e 's/^#\(group   notConfigGroup v2c           notConfigUser\)/\1/' \
       -e 's/^#\(view    systemview    included   .1.3.6.1.2.1.1\)/\1/' \
       -e 's/^#\(view    systemview    included   .1.3.6.1.2.1.25.1.1\)/\1/' \
       -e 's/^#\(access  notConfigGroup ""      any       noauth    exact  systemview none none\)/\1/' \
       -e 's/^#\(syslocation Unknown (edit \/etc\/snmp\/snmpd.conf)\)/\1/' \
       -e 's/^#\(syscontact Root <root@localhost> (configure \/etc\/snmp\/snmp.local.conf)\)/\1/' \
       /etc/snmp/snmpd.conf

# Ajouter ou modifier les valeurs pour syslocation et syscontact
sed -i 's/syslocation Unknown (edit \/etc\/snmp\/snmpd.conf)/syslocation "MyLocation"/' /etc/snmp/snmpd.conf
sed -i 's/syscontact Root <root@localhost> (configure \/etc\/snmp\/snmp.local.conf)/syscontact "Admin <admin@example.com>"/' /etc/snmp/snmpd.conf

# Redémarrer le service SNMP
systemctl restart snmpd

# Afficher le statut du service SNMP
systemctl status snmpd


# Ajouter la configuration de firewall (DEV)
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
  <source address="134.157.134.0/24"/>
  <source address="10.11.20.0/22"/>
  <source address="134.157.142.0/24"/>
  <source address="134.157.1.240/23"/>
  <source address="134.157.143.0/24"/>
  <source address="10.11.7.239"/>
  <source address="134.157.23.239"/>
  <source address="134.157.254.8"/>
  <source address="134.157.254.117"/> 
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
firewall-cmd --permanent --add-port=161/udp

# Redémarrer le service firewalld pour appliquer les modifications
systemctl restart firewalld
echo "Le service firewalld a été redémarré."

# Configuration de chronyd
# Sauvegarder le fichier de configuration original de chrony
cp /etc/chrony.conf /etc/chrony.conf.old

# Modifier /etc/chrony.conf pour utiliser la passerelle comme serveur NTP
sed -i "s/^pool /#pool /" /etc/chrony.conf
echo "server $gateway iburst" >> /etc/chrony.conf

# Redémarrer le service chronyd pour appliquer les modifications
systemctl restart chronyd

# Vérifier le statut du service chronyd
systemctl status chronyd
# Pause de 6 secondes
sleep 6

# Vérifier la synchronisation de l'horloge
timedatectl

echo "Configuration de chronyd avec l'adresse IP de la passerelle : $gateway effectuée."

# Mise à jour des paquets
dnf update -y && dnf upgrade -y && dnf autoremove -y && dnf clean all -y

# Retirer X11 pour améliorer les performances et la sécurité
dnf remove -y x11-common libwayland-server0

# Installation des paquets utiles
dnf install -y inxi
# Installation postfix (stoppé et désactivé)
dnf install -y postfix
systemctl stop postfix
systemctl disable postfix
dnf install -y shellcheck
dnf install -y net-tools
dnf install -y psmisc
dnf install -y mailx
dnf install -y mailutils
dnf install -y cyrus-sasl
dnf install -y rsyslog
dnf install -y openssh-clients
dnf install -y wget
dnf install -y htop
dnf install -y dstat
dnf install -y iotop 
dnf install -y lnav
dnf install -y mlocate
dnf install -y man 
dnf install -y tree
dnf install -y bind-utils 
dnf install -y whois
dnf install -y traceroute
dnf install -y unzip
dnf install -y telnet 
dnf install -y lsof
dnf install -y vim
dnf install -y ccze mc tmux rsync

# Modification du /root/.bashrc
cat <<EOF >> /root/.bashrc
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
alias last="last -F"

export PATH="/snap/bin/:\$PATH"
EOF

echo "Contenu ajouté avec succès à /root/.bashrc."

# Sourcer .bashrc
source /root/.bashrc

# Vérifier que tous les services critiques sont en cours d’exécution
systemctl list-units --type=service

# Enregistrement dans RedHat (mmobioh ; Sorbonne@2023)
echo "Enregistrement dans RedHat :"
echo "Nettoyage des informations d'inscription précédentes"
subscription-manager clean
echo "Enregistrement de l'utilisateur [mmobioh]"
subscription-manager register --username=mmobioh --password=Sorbonne@2023
echo "Affichage de la liste des abonnements disponibles"
subscription-manager list --available
echo "Attachement de l'abonnement spécifique identifié par le code de pool [8a85f99977b0c0420177f2a086211111s]"
subscription-manager attach --pool=8a85f99977b0c0420177f2a086211111

# Vidage du contenu des fichiers de journalisation système
> /var/log/wtmp
> /var/log/lastlog

# Suppression history
history -c

# Message de fin de script
echo "********** Fin du script **********"
sleep 3
echo "********** Redémarrage du serveur **********"
sleep 3
reboot
