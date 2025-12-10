#!/bin/bash

# ==========================================
# BASELINE CLI DEBIAN 13 (Post-Install)
# ==========================================

# 1. VÉRIFICATION ROOT
if [[ $EUID -ne 0 ]]; then
   echo "ERREUR: Ce script doit être lancé en tant que root." 
   exit 1
fi

# 2. PRÉ-REQUIS IMMÉDIATS (CURL)
# On s'assure que curl est là avant de faire quoi que ce soit d'autre
echo ">>> Installation du pré-requis: curl..."
apt update
apt install -y curl wget

# Couleurs (maintenant qu'on est sûr que le script tourne)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}>>> Démarrage de la Baseline CLI Debian 13...${NC}"

# -----------------------------------------------------------------
# 3. MISE A JOUR & INSTALLATION BINUTILS
# -----------------------------------------------------------------
echo -e "${GREEN}[1/6] Mise à jour complète et installation des outils...${NC}"
apt upgrade -y

# Liste des outils (curl est déjà là, mais apt vérifiera juste qu'il est à jour)
TOOLS="ssh zip unzip nmap locate ncdu git screen dnsutils net-tools sudo lynx"

apt install -y $TOOLS

# Initialisation de la base de données 'locate'
echo "Mise à jour de l'index locate (updatedb)..."
updatedb

# -----------------------------------------------------------------
# 4. NETBIOS / SAMBA (Réseau local Windows)
# -----------------------------------------------------------------
echo -e "${GREEN}[2/6] Installation Samba et config WINS...${NC}"
apt install -y winbind samba

# Backup de nsswitch
cp /etc/nsswitch.conf /etc/nsswitch.conf.bak

# Ajout de 'wins' à la ligne hosts si absent
if grep -q "wins" /etc/nsswitch.conf; then
    echo "WINS déjà configuré."
else
    echo "Modification de /etc/nsswitch.conf..."
    sed -i 's/^hosts:          files dns/hosts:          files dns wins/' /etc/nsswitch.conf
fi

# -----------------------------------------------------------------
# 5. PERSONNALISATION DU BASH (Couleurs et Alias)
# -----------------------------------------------------------------
echo -e "${GREEN}[3/6] Activation des couleurs et alias dans .bashrc...${NC}"
# Décommenter les lignes pour la couleur et les alias
sed -i "s/# export LS_OPTIONS='--color=auto'/export LS_OPTIONS='--color=auto'/g" /root/.bashrc
sed -i 's/# eval "`dircolors`"/eval "`dircolors`"/g' /root/.bashrc
sed -i "s/# alias ls='ls \$LS_OPTIONS'/alias ls='ls \$LS_OPTIONS'/g" /root/.bashrc
sed -i "s/# alias ll='ls \$LS_OPTIONS -l'/alias ll='ls \$LS_OPTIONS -l'/g" /root/.bashrc
sed -i "s/# alias l='ls \$LS_OPTIONS -lA'/alias l='ls \$LS_OPTIONS -lA'/g" /root/.bashrc

# Application immédiate
source /root/.bashrc

# -----------------------------------------------------------------
# 6. INSTALLATION WEBMIN
# -----------------------------------------------------------------
echo -e "${GREEN}[4/6] Installation de Webmin...${NC}"
# Utilisation de curl (qui est maintenant garanti d'être installé)
curl -o webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
chmod +x webmin-setup-repo.sh
./webmin-setup-repo.sh
apt install -y webmin --install-recommends
rm webmin-setup-repo.sh

# -----------------------------------------------------------------
# 7. BONUS FUN
# -----------------------------------------------------------------
echo -e "${GREEN}[5/6] Installation des BSD Games...${NC}"
apt install -y bsdgames

# -----------------------------------------------------------------
# 8. CONFIGURATION RÉSEAU (TEMPLATE)
# -----------------------------------------------------------------
echo -e "${GREEN}[6/6] Configuration Réseau...${NC}"
echo -e "${RED}RAPPEL : Modification IP manuelle requise pour éviter la déconnexion.${NC}"
echo "Voici le modèle à copier dans /etc/network/interfaces :"
echo "----------------------------------------------------"
cat <<EOF
# IP FIXE (Exemple)
auto ens33
iface ens33 inet static
    address 192.168.1.50/24
    gateway 192.168.1.1
    # dns-nameservers 1.1.1.1 8.8.8.8
EOF
echo "----------------------------------------------------"

# -----------------------------------------------------------------
# FIN
# -----------------------------------------------------------------
echo -e "${BLUE}>>> INSTALLATION TERMINÉE !${NC}"
echo "Webmin : https://$(hostname -I | awk '{print $1}'):10000"