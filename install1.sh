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

# Bestehender Code (z.B. Paketinstallationen) könnte hier stehen
# ...

# Benutzerabfrage für USB-Synchronisation
read -p "Möchtest du den ersten USB-Stick auf einen zweiten USB-Stick im RAID1 (rsync) synchronisieren? (y/n): " USE_USB_SYNC
if [ "$USE_USB_SYNC" == "y" ]; then
    echo "USB_SYNC_ENABLED=1" > ~/config.sh
else
    echo "USB_SYNC_ENABLED=0" > ~/config.sh
fi

# Installation von rsync (falls Synchronisation gewünscht)
if [ "$USE_USB_SYNC" == "y" ]; then
    sudo apt install -y rsync
    check_success
fi

# ... (weiterer bestehender Code)
