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
if [ "$USB_SYNC_ENABLED" != "1" ]; then
    echo -e "${GREEN}USB-Synchronisation ist deaktiviert. Skript wird beendet.${NC}"
    exit 0
fi

# USB-Stick erkennen (erster nicht-sda-Disk)
USB_DEVICE=$(lsblk -o NAME,TYPE,SIZE,MOUNTPOINT | grep -i "disk" | grep -v "sda" | head -n 1 | awk '{print $1}')
if [ -z "$USB_DEVICE" ]; then
    echo -e "${RED}Kein USB-Stick gefunden.${NC}"
    exit 1
fi

# Vollständiger Gerätepfad
USB_DEVICE="/dev/$USB_DEVICE"

# USB-Stick formatieren (nur wenn kein Dateisystem vorhanden)
if ! blkid "$USB_DEVICE" > /dev/null 2>&1; then
    echo -e "${GREEN}Formatiere USB-Stick (${USB_DEVICE}) mit ext4...${NC}"
    sudo mkfs.ext4 "$USB_DEVICE"
    check_success
fi

# Mount-Punkt erstellen und mounten
MOUNT_POINT="/media/usb_sync"
sudo mkdir -p "$MOUNT_POINT"
sudo mount "$USB_DEVICE" "$MOUNT_POINT"
check_success

# Erste Synchronisation durchführen (angenommener Quellpfad: /data)
SOURCE_DIR="/data"  # Hier den tatsächlichen Quellpfad anpassen!
sudo rsync -av --delete "$SOURCE_DIR/" "$MOUNT_POINT/"
check_success

# Cron-Job für stündliche Synchronisation einrichten
CRON_FILE="/etc/cron.d/usb_sync"
echo "0 * * * * root rsync -av --delete $SOURCE_DIR/ $MOUNT_POINT/" | sudo tee "$CRON_FILE"
check_success

echo -e "${GREEN}USB-Stick wurde erkannt, eingerichtet und synchronisiert.${NC}"
