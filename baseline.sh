#!/usr/bin/env bash
# ===============================================================
# Auto-install curl si curl n'est pas présent
# → permet de lancer le script même sur une Debian 13 toute fraîche sans rien
# ===============================================================
if ! command -v curl >/dev/null 2>&1; then
    echo "curl non trouvé → installation automatique..."
    apt-get update && apt-get install -y curl
fi

# ===============================================================
# Baseline CLI Debian 13 (Trixie) - Version définitive avec auto-curl
# Repo : https://github.com/AndySpk/debian-baseline
# Auteur : AndySpk + Grok
# ===============================================================

set -euo pipefail

LOGFILE="/var/log/baseline_debian_cli.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "================================================================"
echo "  Début de la baseline CLI Debian - $(date)"
echo "================================================================"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Vérification root
[[ $EUID -eq 0 ]] || { echo "Ce script doit être exécuté en root"; exit 1; }

# 1. Mise à jour complète
log "1. Mise à jour complète du système..."
apt update && apt full-upgrade -y

# 2. Paquets essentiels
log "2. Installation des paquets essentiels..."
apt install -y --no-install-recommends \
    openssh-server zip unzip nmap locate ncdu curl git screen dnsutils \
    net-tools sudo lynx ca-certificates bash-completion ipcalc

updatedb &>/dev/null || true
log "Paquets installés + base locate mise à jour"

# 3. NetBIOS (optionnel)
read -p "Installer winbind/samba pour résolution NetBIOS (réseaux locaux uniquement) ? [o/N] " netbios
if [[ $netbios =~ ^[Oo]$ ]]; then
    log "3. Installation winbind + samba"
    apt install -y winbind samba
    sed -i '/^hosts:/ s/$/ wins/' /etc/nsswitch.conf
    log "NetBIOS activé"
else
    log "3. NetBIOS désactivé"
fi

# 4. Personnalisation .bashrc root
log "4. Activation alias/couleurs dans /root/.bashrc"
sed -i '9,13s/^#//' /root/.bashrc
source /root/.bashrc 2>/dev/null || true

# 5. Configuration réseau IP fixe
log "5. Configuration réseau en IP fixe"
echo
ip -br link show
echo
read -p "Nom de l'interface (ex: ens18, enp0s3) : " INTERFACE
read -p "Adresse IP avec CIDR (ex: 192.168.1.50/24) : " IP_ADDRESS
read -p "Passerelle par défaut : " GATEWAY
read -p "DNS principal (ex: 1.1.1.1) : " DNS_SERVER
read -p "Domaine de recherche (facultatif) : " SEARCH_DOMAIN
read -p "Hostname de la machine : " HOSTNAME

NETMASK=$(ipcalc "$IP_ADDRESS" | grep Netmask | awk '{print $4}')

cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s) 2>/dev/null || true

cat > /etc/network/interfaces << 'EOF'
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet static
    address ${IP_ADDRESS%/*}
    netmask $NETMASK
    gateway $GATEWAY
EOF

cat > /etc/resolv.conf << 'EOF'
nameserver $DNS_SERVER
${SEARCH_DOMAIN:+search $SEARCH_DOMAIN}
EOF

echo "$HOSTNAME" > /etc/hostname
hostnamectl set-hostname "$HOSTNAME"

if command -v ifup >/dev/null 2>&1; then
    ifdown "$INTERFACE" || true
    ifup "$INTERFACE"
else
else
    systemctl restart systemd-networkd || true
fi

log "Réseau configuré : $IP_ADDRESS → gateway $GATEWAY"

# 6. Webmin
read -p "Installer Webmin (interface web) ? [o/N] " webmin
if [[ $webmin =~ ^[Oo]$ ]]; then
    log "6. Installation de Webmin..."
    wget -O webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin
