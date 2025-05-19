#!/bin/bash

# Farben für die Ausgabe definieren
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Funktion zum Überprüfen des letzten Befehls
check_success() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Fehler bei der Ausführung des letzten Befehls. Skript wird abgebrochen.${NC}"
        exit 1
    fi
}

# Lade Konfigurationsvariablen
if [ ! -f ~/config.sh ]; then
    echo -e "${RED}Konfigurationsdatei ~/config.sh nicht gefunden. Bitte führe zuerst 'install_part1.sh' aus.${NC}"
    exit 1
fi
source ~/config.sh

# Überprüfe, ob die statische IP gesetzt ist
if [ "$SET_NETWORK_MANUALLY" == "y" ]; then
    LOCAL_IP=$STATIC_IP
else
    LOCAL_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
fi

# Statische IP konfigurieren (falls gewünscht)
if [ "$SET_NETWORK_MANUALLY" == "y" ]; then
    echo -e "${GREEN}Erstelle Skript für statische IP...${NC}"
    cat << EOF > ~/set_static_ip.sh
#!/bin/bash
echo "interface eth0
static ip_address=${STATIC_IP}/24
static routers=${GATEWAY}
static domain_name_servers=${DNS_SERVERS}" | sudo tee /etc/dhcpcd.conf > /dev/null
sudo systemctl restart dhcpcd
EOF
    chmod +x ~/set_static_ip.sh
    echo "@reboot $USER ~/set_static_ip.sh" | sudo tee /etc/cron.d/set_static_ip
    check_success
    sudo bash ~/set_static_ip.sh
    check_success
fi

# Bluetooth und WiFi optional deaktivieren
if [ "$DISABLE_BT" == "y" ]; then
    echo -e "${GREEN}Deaktiviere Bluetooth...${NC}"
    echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt
    check_success
fi

if [ "$DISABLE_WIFI" == "y" ]; then
    echo -e "${GREEN}Deaktiviere WiFi...${NC}"
    echo "dtoverlay=disable-wifi" | sudo tee -a /boot/config.txt
    check_success
fi

# DynDNS-Client mit ddclient einrichten
echo -e "${GREEN}Richte DynDNS ein...${NC}"
case $DYNDNS_SERVICE in
    "http.net")
        cat << EOF > ~/docker/ddclient/config/ddclient.conf
protocol=dyndns2
use=web
server=ddns.routing.net
login=$DYNDNS_USER
password=$DYNDNS_PASS
$DOMAIN
EOF
        ;;
    "duckdns")
        cat << EOF > ~/docker/ddclient/config/ddclient.conf
protocol=duckdns
use=web
login=$DYNDNS_USER
password=$DYNDNS_PASS
$DOMAIN
EOF
        ;;
    "noip")
        cat << EOF > ~/docker/ddclient/config/ddclient.conf
protocol=noip
use=web
login=$DYNDNS_USER
password=$DYNDNS_PASS
$DOMAIN
EOF
        ;;
esac

sg docker -c "docker run -d \
  --name ddclient \
  -v ~/docker/ddclient/config:/config \
  --restart=unless-stopped \
  linuxserver/ddclient"
check_success
echo -e "${GREEN}DynDNS wurde eingerichtet. Überprüfe die Logs mit 'docker logs ddclient', falls Probleme auftreten.${NC}"

# NGINX Proxy Manager installieren
echo -e "${GREEN}Installiere NGINX Proxy Manager...${NC}"
sg docker -c "docker run -d \
  --name nginx-proxy-manager \
  --network proxy_net \
  -p 80:80 \
  -p 443:443 \
  -p 81:81 \
  -v ~/docker/proxy/data:/data \
  -v ~/docker/proxy/letsencrypt:/etc/letsencrypt \
  --restart=unless-stopped \
  jc21/nginx-proxy-manager"
check_success

# Benutzer auffordern, NGINX Proxy Manager zu konfigurieren
echo -e "${GREEN}NGINX Proxy Manager wurde gestartet. Bitte öffne http://$LOCAL_IP:81 im Browser und konfiguriere die Proxy Hosts für alle Dienste.${NC}"
echo "Standard-Login: admin@example.com / changeme"
read -p "Drücke Enter, wenn du NGINX Proxy Manager konfiguriert hast..."

# CapRover installieren
echo -e "${GREEN}Installiere CapRover...${NC}"
sg docker -c "docker run -d \
  --name caprover \
  --network proxy_net \
  -p 3000:3000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/docker/caprover:/captain/data \
  --restart=unless-stopped \
  caprover/caprover"
check_success

# NextcloudPi installieren
echo -e "${GREEN}Installiere NextcloudPi...${NC}"
sg docker -c "docker run -d \
  --name nextcloudpi \
  --network proxy_net \
  -p 8081:80 \
  -p 8443:443 \
  -p 4443:4443 \
  -v ~/docker/nextcloud:/data \
  --restart=unless-stopped \
  ownyourbits/nextcloudpi"
check_success

# Vaultwarden installieren
echo -e "${GREEN}Installiere Vaultwarden...${NC}"
sg docker -c "docker run -d \
  --name vaultwarden \
  --network proxy_net \
  -p 8082:80 \
  -v ~/docker/bitwarden:/data \
  --restart=unless-stopped \
  vaultwarden/server"
check_success

# Etherpad installieren
echo -e "${GREEN}Installiere Etherpad...${NC}"
sg docker -c "docker run -d \
  --name etherpad \
  --network proxy_net \
  -p 9001:9001 \
  -v ~/docker/etherpad:/opt/etherpad-lite/var \
  --restart=unless-stopped \
  etherpad/etherpad"
check_success

# USB-Synchronisation überprüfen (falls aktiviert)
if [ "$USE_USB_SYNC" == "y" ]; then
    echo -e "${GREEN}USB-Synchronisation ist aktiviert. Stecke den zweiten USB-Stick ein, um die Synchronisation zu starten.${NC}"
fi

# Abschlussmeldung
echo -e "${GREEN}Teil 2 der Installation abgeschlossen!${NC}"
echo -e "${GREEN}Bitte starte das System neu, um die Änderungen zu übernehmen.${NC}"
echo -e "${GREEN}Führe nach dem Neustart 'install_part3.sh' aus, falls du Raspberry Pi OS Desktop verwendest.${NC}"
