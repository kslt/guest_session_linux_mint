#!/bin/bash

# --- KONFIGURATION ---
USER_NAME="scout_user"
GROUP_NAME="scouter"
TEMPLATE_DIR="/opt/scout_template"
CLEANUP_SCRIPT="/usr/local/bin/restore_scout.sh"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf.d/70-linuxmint.conf"

echo "--- Startar konfiguration av Scout-konto ---"

# 1. Skapa gruppen om den inte finns
if ! getent group $GROUP_NAME > /dev/null; then
    groupadd $GROUP_NAME
    echo "[OK] Gruppen $GROUP_NAME skapad."
fi

# 2. Skapa användaren om den inte finns
if ! id -u $USER_NAME > /dev/null 2>&1; then
    # Skapar användaren med gruppen och sätter ett tillfälligt lösenord 'scout'
    useradd -m -g $GROUP_NAME -s /bin/bash $USER_NAME
    echo "$USER_NAME:scout" | chpasswd
    echo "[OK] Användaren $USER_NAME skapad (Lösenord: scout)."
fi

# 3. Skapa en "Guld-kopia" (mall) av hemkatalogen
echo "Skapar mall för återställning..."
mkdir -p $TEMPLATE_DIR
cp -rp /home/$USER_NAME/. $TEMPLATE_DIR/
chown -R root:root $TEMPLATE_DIR
echo "[OK] Mall skapad i $TEMPLATE_DIR."

# 4. Skapa själva återställningsskriptet
echo "Skapar utloggningsskriptet $CLEANUP_SCRIPT..."
cat << 'EOF' > $CLEANUP_SCRIPT
#!/bin/bash
# Detta skript körs av LightDM vid utloggning
USER="scout_user"
GROUP="scouter"
TEMPLATE="/opt/scout_template"

# Logga aktivitet för felsökning
echo "Rensar konto för $USER vid $(date)" >> /tmp/scout_restore.log

# Rensa nuvarande hemkatalog
rm -rf /home/$USER/*
rm -rf /home/$USER/.* 2>/dev/null

# Kopiera tillbaka från mallen
cp -rp $TEMPLATE/. /home/$USER/

# Återställ rättigheter så användaren kan logga in igen
chown -R $USER:$GROUP /home/$USER/
EOF

chmod +x $CLEANUP_SCRIPT
echo "[OK] Återställningsskript skapat."

# 5. Konfigurera LightDM att köra skriptet vid utloggning
echo "Konfigurerar LightDM..."
mkdir -p /etc/lightdm/lightdm.conf.d/
if [ -f "$LIGHTDM_CONF" ]; then
    # Ta bort gammal rad om den finns för att undvika dubbletter
    sed -i '/session-cleanup-script=/d' $LIGHTDM_CONF
fi

# Lägg till raden under [Seat:*]
if ! grep -q "\[Seat:\*\]" $LIGHTDM_CONF 2>/dev/null; then
    echo "[Seat:*]" >> $LIGHTDM_CONF
fi
sed -i '/\[Seat:\*\]/a session-cleanup-script='${CLEANUP_SCRIPT} $LIGHTDM_CONF

echo "[OK] LightDM konfigurerad."

# 6. Lås ner kritiska mappar (Valfritt men rekommenderat)
# Hindra scouten från att se andra hemmappar
chmod 700 /home/* --ignore-fail-on-non-empty 2>/dev/null
chmod 755 /home/$USER_NAME

echo "--- KLART! ---"
echo "1. Logga in som '$USER_NAME' (lösenord: scout)."
echo "2. Gör de inställningar du vill ha (Firefox, skrivbord, etc)."
echo "3. VIKTIGT: När du är nöjd, kör detta kommando som admin:"
echo "   sudo cp -rp /home/$USER_NAME/. $TEMPLATE_DIR/"
echo "--------------------------------------------"
