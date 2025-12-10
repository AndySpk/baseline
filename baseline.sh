#!/bin/bash

# ==========================================
# BASELINE CLI DEBIAN 13 (V2 - Safe Mode)
# ==========================================

# 1. VÉRIFICATION ROOT
if [[ $EUID -ne 0 ]]; then
   echo "ERREUR: Ce script doit être lancé en tant que root." 
   exit 1
fi

# 2. PRÉ-REQUIS IMMÉDIATS
echo ">>> Installation des pré-requis..."
export DEBIAN_FRONTEND=noninteractive
apt update -q
apt install -y -q curl wget

# Couleurs
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}>>> Démarrage de la Baseline CLI Debian 13...${NC}"

# -----------------------------------------------------------------
# 3. MISE A JOUR & OUTILS
# -----------------------------------------------------------------
echo -e "${GREEN}[1/6] Mise à jour et installation des outils...${NC}"
# On évite les prompts interactifs
apt upgrade -y -q

TOOLS="ssh zip unzip nmap locate ncdu git screen dnsutils net-tools sudo lynx"
apt install -y -q $TOOLS

echo "Mise à jour de l'index locate..."
updatedb

# -----------------------------------------------------------------
# 4. NETBIOS / SAMBA
# -----------------------------------------------------------------
echo -e "${GREEN}[2/6] Installation Samba...${NC}"
apt install -y -q winbind samba

# Backup et Config
cp /etc/nsswitch.conf /etc/nsswitch.conf.bak
if grep -q "wins" /etc/nsswitch.conf; then
    echo "WINS déjà configuré."
else
    echo "Activation WINS..."
    sed -i 's/^hosts:          files dns/hosts:          files dns wins/' /etc/nsswitch.conf
fi

# -----------------------------------------------------------------
# 5. PERSONNALISATION BASH
# -----------------------------------------------------------------
echo -e "${GREEN}[3/6] Activation couleurs .bashrc...${NC}"
sed -i "s/# export LS_OPTIONS='--color=auto'/export LS_OPTIONS='--color=auto'/g" /root/.bashrc
sed -i 's/# eval "`dircolors`"/eval "`dircolors`"/g' /root/.bashrc
sed -i "s/# alias ls='ls \$LS_OPTIONS'/alias ls='ls \$LS_OPTIONS'/g" /root/.bashrc
sed -i "s/# alias ll='ls \$LS_OPTIONS -l'/alias ll='ls \$LS_OPTIONS -l'/g" /root/.bashrc
sed -i "s/# alias l='ls \$LS_OPTIONS -lA'/alias l='ls \$LS_OPTIONS -lA'/g" /root/.bashrc

# -----------------------------------------------------------------
# 6. WEBMIN
# -----------------------------------------------------------------
echo -e "${GREEN}[4/6] Installation Webmin...${NC}"
curl -o webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
chmod +x webmin-setup-repo.sh
./webmin-setup-repo.sh > /dev/null 2>&1
apt install -y -q webmin --install-recommends
rm webmin-setup-repo.sh

# -----------------------------------------------------------------
# 7. BONUS
# -----------------------------------------------------------------
echo -e "${GREEN}[5/6] Installation Jeux...${NC}"
apt install -y -q bsdgames

# -----------------------------------------------------------------
# 8. CONFIGURATION RÉSEAU (Mode Echo Simple)
# -----------------------------------------------------------------
echo -e "${GREEN}[6/6] Terminé !${NC}"
echo "----------------------------------------------------"
echo "MODELE A COPIER DANS /etc/network/interfaces :"
echo ""
echo "# IP FIXE (Exemple)"
echo "auto ens33"
echo "iface ens33 inet static"
echo "    address 192.168.1.50/24"
echo "    gateway 192.168.1.1"
echo "    # dns-nameservers 1.1.1.1 8.8.8.8"
echo "----------------------------------------------------"
echo "Webmin : https://$(hostname -I | awk '{print $1}'):10000"
