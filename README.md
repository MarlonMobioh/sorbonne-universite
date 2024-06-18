Pour lancer le script :

# ADD AUTHORIZED_KEYS FILE
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/add_authorized_key_file.sh
bash add_authorized_key_file.sh

# ADD NEW_USERS FILE


# ADD SUBSCRIPTION MANAGER REDHAT
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/subscription_manager_redhat.sh
bash subscription_manager_redhat.sh

# DEV DEBIAN 11-12
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/install_debian11-12_dev_mmo.sh
bash /tmp/install_debian11-12_dev_mmo.sh

# PREPROD_PRIV DEBIAN 11-12
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/install_debian11-12_preprod_priv_mmo.sh
bash /tmp/install_debian11-12_preprod_priv_mmo.sh

# PROD_PRIV DEBIAN 11-12
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/install_debian11-12_prod_priv_mmo.sh
bash /tmp/install_debian11-12_prod_priv_mmo.sh

# PREPROD DEBIAN 11-12
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/install_debian11-12_preprod_mmo.sh
bash /tmp/install_debian11-12_preprod_mmo.sh

# PROD DEBIAN 11-12
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/install_debian11-12_prod_mmo.sh
bash /tmp/install_debian11-12_prod_mmo.sh

# PROD REDHAT 9
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/install_redhat8-9_prod_mmo.sh
bash /tmp/install_redhat8-9_prod_mmo.sh

# DEV REDHAT 9
cd /tmp
wget https://raw.githubusercontent.com/MarlonMobioh/SU/main/install_redhat8-9_dev_mmo.sh
bash /tmp/install_redhat8-9_dev_mmo.sh
