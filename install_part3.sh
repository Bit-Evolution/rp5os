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

# Überprüfe, ob Desktop-Sicherheit konfiguriert werden soll
if [ "$USE_DESKTOP" == "y" ]; then
    echo -e "${GREEN}Richte Desktop-Sicherheit ein...${NC}"
    cat << 'EOF' > ~/secure_desktop.sh
#!/bin/bash
# UFW aktivieren und Standardregeln setzen
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Ports für Dienste freigeben
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 81/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 8081/tcp
sudo ufw allow 8443/tcp
sudo ufw allow 4443/tcp
sudo ufw allow 8082/tcp
sudo ufw allow 9001/tcp

# UFW aktivieren
sudo ufw enable
echo -e "${GREEN}Firewall wurde konfiguriert. Bitte starte den Raspberry Pi neu, um die Änderungen zu übernehmen.${NC}"
EOF
    chmod +x ~/secure_desktop.sh
    bash ~/secure_desktop.sh
    check_success
else
    echo -e "${GREEN}Desktop-Sicherheit nicht erforderlich.${NC}"
fi

# Abschlussmeldung
echo -e "${GREEN}Teil 3 der Installation abgeschlossen!${NC}"
echo -e "${GREEN}Bitte starte das System neu, um die Firewall-Änderungen zu übernehmen.${NC}"
