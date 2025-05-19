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

# Sicherstellen, dass das Skript als root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Dieses Skript muss als root ausgeführt werden. Bitte verwende 'sudo' oder melde dich als root an.${NC}"
    exit 1
fi

# Lade Konfigurationsvariablen, falls vorhanden
if [ -f ~/config.sh ]; then
    source ~/config.sh
else
    echo -e "${RED}Konfigurationsdatei ~/config.sh nicht gefunden. Deinstallation kann nicht fortgesetzt werden.${NC}"
    exit 1
fi

# Bestätigung vom Benutzer einholen
read -p "Bist du sicher, dass du die Installation deinstallieren möchtest? Dies wird alle Dienste stoppen, Daten löschen und Konfigurationen zurücksetzen. (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo -e "${GREEN}Deinstallation abgebrochen.${NC}"
    exit 0
fi

# Dienste stoppen und entfernen
echo -e "${GREEN}Stoppe und entferne Docker-Dienste...${NC}"
docker stop nginx-proxy-manager caprover nextcloudpi vaultwarden etherpad ddclient 2>/dev/null
docker rm nginx-proxy-manager caprover nextcloudpi vaultwarden etherpad ddclient 2>/dev/null
check_success

# Docker-Netzwerk entfernen
echo -e "${GREEN}Entferne Docker-Netzwerk proxy_net...${NC}"
docker network rm proxy_net 2>/dev/null
check_success

# Entferne Docker-Verzeichnisse
echo -e "${GREEN}Entferne Docker-Datenverzeichnisse...${NC}"
rm -rf ~/docker
check_success

# Entferne USB-Synchronisation (falls aktiviert)
if [ "$USE_USB_SYNC" == "y
