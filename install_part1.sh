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

# Automatische Erkennung der lokalen IP-Adresse
LOCAL_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}Konnte lokale IP-Adresse nicht ermitteln. Bitte überprüfe die Netzwerkverbindung.${NC}"
    exit 1
fi

# Benutzerabfragen mit Eingabevalidierung
read -p "Gib deine Domain ein (z.B. example.com oder deine-subdomain.duckdns.org): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain darf nicht leer sein.${NC}"
    exit 1
fi

read -p "Gib deine E-Mail-Adresse ein (für Let's Encrypt): " EMAIL
if [ -z "$EMAIL" ]; then
    echo -e "${RED}E-Mail-Adresse darf nicht leer sein.${NC}"
    exit 1
fi

# DynDNS-Dienst auswählen
echo "Wähle den DynDNS-Dienst für die Domain $DOMAIN:"
echo "1. http.net"
echo "2. DuckDNS"
echo "3. No-IP"
read -p "Gib die Nummer des gewünschten Dienstes ein: " DYNDNS_CHOICE

case $DYNDNS_CHOICE in
    1) DYNDNS_SERVICE="http.net" ;;
    2) DYNDNS_SERVICE="duckdns" ;;
    3) DYNDNS_SERVICE="noip" ;;
    *) echo -e "${RED}Ungültige Auswahl.${NC}"; exit 1 ;;
esac

# DynDNS-Zugangsdaten basierend auf dem Dienst abfragen
if [ "$DYNDNS_SERVICE" == "duckdns" ]; then
    read -p "Gib deinen DuckDNS-Token für $DOMAIN ein: " DYNDNS_TOKEN
    if [ -z "$DYNDNS_TOKEN" ]; then
        echo -e "${RED}Token darf nicht leer sein.${NC}"
        exit 1
    fi
    DYNDNS_USER="unused"
    DYNDNS_PASS="$DYNDNS_TOKEN"
else
    read -p "Gib deinen DynDNS-Benutzernamen für $DOMAIN ein: " DYNDNS_USER
    if [ -z "$DYNDNS_USER" ]; then
        echo -e "${RED}Benutzername darf nicht leer sein.${NC}"
        exit 1
    fi
    read -s -p "Gib dein DynDNS-Passwort für $DOMAIN ein: " DYNDNS_PASS
    echo
    if [ -z "$DYNDNS_PASS" ]; then
        echo -e "${RED}Passwort darf nicht leer sein.${NC}"
        exit 1
    fi
fi

read -p "Möchtest du das Netzwerk manuell konfigurieren? (y/n): " SET_NETWORK_MANUALLY
if [ "$SET_NETWORK_MANUALLY" == "y" ]; then
    read -p "Gib die statische IP-Adresse ein (z.B. 192.168.1.100): " STATIC_IP
    if [ -z "$STATIC_IP" ]; then
        echo -e "${RED}Statische IP darf nicht leer sein.${NC}"
        exit 1
    fi
    read -p "Gib das Gateway ein (z.B. 192.168.1.1): " GATEWAY
    if [ -z "$GATEWAY" ]; then
        echo -e "${RED}Gateway darf nicht leer sein.${NC}"
        exit 1
    fi
    read -p "Gib die DNS-Server ein (z.B. 192.168.1.1,8.8.8.8): " DNS_SERVERS
    if [ -z "$DNS_SERVERS" ]; then
        echo -e "${RED}DNS-Server dürfen nicht leer sein.${NC}"
        exit 1
    fi
else
    STATIC_IP=$LOCAL_IP
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    DNS_SERVERS=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | paste -sd "," -)
fi

read -p "Möchtest du Bluetooth deaktivieren? (y/n): " DISABLE_BT
read -p "Möchtest du WiFi deaktivieren? (y/n): " DISABLE_WIFI
read -p "Verwendest du Raspberry Pi OS mit Desktop? (y/n): " USE_DESKTOP

# USB-Synchronisation abfragen
read -p "Möchtest du den ersten USB-Stick auf einen zweiten USB-Stick im RAID1 (rsync) synchronisieren? (y/n): " USE_USB_SYNC
read -p "Gib den Mount-Punkt des ersten USB-Sticks ein (z.B. /mnt/usb1): " USB_SOURCE_DIR
if [ "$USE_USB_SYNC" == "y" ] && [ -z "$USB_SOURCE_DIR" ]; then
    echo -e "${RED}Mount-Punkt des ersten USB-Sticks darf nicht leer sein.${NC}"
    exit 1
fi

# System aktualisieren
echo -e "${GREEN}Aktualisiere das System...${NC}"
sudo apt update && sudo apt upgrade -y
check_success

# Erforderliche Pakete installieren
echo -e "${GREEN}Installiere erforderliche Pakete...${NC}"
sudo apt install -y curl git ufw rsync
check_success

# Docker und Docker Compose installieren
echo -e "${GREEN}Installiere Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
check_success
sudo usermod -aG docker $USER
echo -e "${GREEN}Hinweis: Du musst dich abmelden und wieder anmelden, um die Gruppenänderung zu übernehmen.${NC}"

echo -e "${GREEN}Installiere Docker Compose...${NC}"
sudo apt install -y docker-compose
check_success

# Verzeichnisse für Docker-Daten erstellen
echo -e "${GREEN}Erstelle Verzeichnisse für Docker-Daten...${NC}"
mkdir -p ~/docker/{proxy,caprover,nextcloud,bitwarden,etherpad,ddclient/config}
check_success

# Docker-Netzwerk für Proxy erstellen
echo -e "${GREEN}Erstelle Docker-Netzwerk proxy_net...${NC}"
sg docker -c "docker network create proxy_net" || true
check_success

# USB-Synchronisation einrichten (falls gewünscht)
if [ "$USE_USB_SYNC" == "y" ]; then
    echo -e "${GREEN}Erstelle USB-Synchronisationsskript /usr/local/bin/usb_sync_setup.sh...${NC}"
    cat << EOF > /usr/local/bin/usb_sync_setup.sh
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

# Prüfen, ob USB-Synchronisation aktiviert ist
source ~/config.sh
if [ "\$USE_USB_SYNC" != "y" ]; then
    echo -e "\${GREEN}USB-Synchronisation ist deaktiviert. Skript wird beendet.\${NC}"
    exit 0
fi

# USB-Stick erkennen (erster nicht-sda-Disk)
USB_DEVICE=\$(lsblk -o NAME,TYPE,SIZE,MOUNTPOINT | grep -i "disk" | grep -v "sda" | head -n 1 | awk '{print \$1}')
if [ -z "\$USB_DEVICE" ]; then
    echo -e "\${RED}Kein USB-Stick gefunden.\${NC}"
    exit 1
fi

# Vollständiger Gerätepfad
USB_DEVICE="/dev/\$USB_DEVICE"

# USB-Stick formatieren (nur wenn kein Dateisystem vorhanden)
if ! blkid "\$USB_DEVICE" > /dev/null 2>&1; then
    echo -e "\${GREEN}Formatiere USB-Stick (\${USB_DEVICE}) mit ext4...\${NC}"
    sudo mkfs.ext4 "\$USB_DEVICE"
    check_success
fi

# Mount-Punkt erstellen und mounten
MOUNT_POINT="/media/usb_sync"
sudo mkdir -p "\$MOUNT_POINT"
sudo mount "\$USB_DEVICE" "\$MOUNT_POINT"
check_success

# Erste Synchronisation durchführen
sudo rsync -av --delete "$USB_SOURCE_DIR/" "\$MOUNT_POINT/"
check_success

# Cron-Job für stündliche Synchronisation einrichten
CRON_FILE="/etc/cron.d/usb_sync"
echo "0 * * * * root rsync -av --delete $USB_SOURCE_DIR/ \$MOUNT_POINT/" | sudo tee "\$CRON_FILE"
check_success

echo -e "\${GREEN}USB-Stick wurde erkannt, eingerichtet und synchronisiert.\${NC}"
EOF
    sudo chmod +x /usr/local/bin/usb_sync_setup.sh
    check_success

    echo -e "${GREEN}Erstelle udev-Regel /etc/udev/rules.d/99-usb-sync.rules...${NC}"
    echo 'ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[b-z]", RUN+="/usr/local/bin/usb_sync_setup.sh"' | sudo tee /etc/udev/rules.d/99-usb-sync.rules
    check_success

    echo -e "${GREEN}Aktualisiere udev-Regeln...${NC}"
    sudo udevadm control --reload-rules && sudo udevadm trigger
    check_success
fi

# Variablen in config.sh speichern
echo -e "${GREEN}Speichere Konfigurationsvariablen...${NC}"
cat << EOF > ~/config.sh
#!/bin/bash
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
STATIC_IP="$STATIC_IP"
GATEWAY="$GATEWAY"
DNS_SERVERS="$DNS_SERVERS"
DISABLE_BT="$DISABLE_BT"
DISABLE_WIFI="$DISABLE_WIFI"
USE_DESKTOP="$USE_DESKTOP"
DYNDNS_SERVICE="$DYNDNS_SERVICE"
DYNDNS_USER="$DYNDNS_USER"
DYNDNS_PASS="$DYNDNS_PASS"
SET_NETWORK_MANUALLY="$SET_NETWORK_MANUALLY"
USE_USB_SYNC="$USE_USB_SYNC"
USB_SOURCE_DIR="$USB_SOURCE_DIR"
EOF
check_success

# Abschlussmeldung
echo -e "${GREEN}Teil 1 der Installation abgeschlossen!${NC}"
echo -e "${GREEN}Bitte melde dich ab und wieder an, um die Docker-Gruppenänderung zu übernehmen.${NC}"
echo -e "${GREEN}Führe danach 'install_part2.sh' aus.${NC}"
