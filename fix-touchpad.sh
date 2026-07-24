#!/bin/bash
#
# fix-touchpad.sh (v3)
# Corrige le problème de souris/touchpad i2c-hid non détecté
# sur Lenovo A475 (et modèles similaires) sous Linux Mint.
#
# - Détection fine par ID ACPI (ELAN/SYNA/etc.)
# - Bind forcé si aucun driver n'est attaché (pas seulement rebind)
# - Vérification que le touchpad est bien détecté après coup
# - Escalade automatique vers un cycle de veille réel si besoin
# - Installe un correctif persistant : au boot ET après chaque réveil
#
# Usage : sudo bash fix-touchpad.sh
#

set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Ce script doit être exécuté avec sudo :"
    echo "   sudo bash fix-touchpad.sh"
    exit 1
fi

# --- 0. Vérification du modèle de machine ---
# Adapte MODEL_PATTERNS à la valeur exacte remontée par ton parc de machines.
# Pour connaître la valeur exacte sur une machine donnée :
#   cat /sys/class/dmi/id/product_name
#   cat /sys/class/dmi/id/product_version
MODEL_PATTERNS="A475"

PRODUCT_NAME="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)"
PRODUCT_VERSION="$(cat /sys/class/dmi/id/product_version 2>/dev/null || echo unknown)"

if ! echo "$PRODUCT_NAME $PRODUCT_VERSION" | grep -qiE "$MODEL_PATTERNS"; then
    echo "ℹ️  Modèle détecté : $PRODUCT_NAME / $PRODUCT_VERSION"
    echo "    Ce n'est pas un Lenovo A475 (ou modèle visé) -> aucune action."
    exit 0
fi

echo "✅ Modèle Lenovo A475 (ou compatible) détecté : $PRODUCT_NAME"
echo

APPLY_SCRIPT="/usr/local/sbin/fix-touchpad-apply.sh"

echo "======================================================"
echo "  Installation du correctif touchpad/souris i2c-hid"
echo "======================================================"
echo

# --- Écriture du script "moteur" qui fait le vrai travail ---
# Il sera appelé au boot, après réveil, et maintenant tout de suite.
echo "[1/3] Écriture du script de correction (${APPLY_SCRIPT})..."

cat > "$APPLY_SCRIPT" <<'ENGINE'
#!/bin/bash
# Script moteur : détecte, corrige, vérifie, et escalade si besoin.
# Ne pas éditer à la main : régénéré par fix-touchpad.sh (installeur).

KNOWN_HID_PATTERNS="ELAN|SYNA|FTCS|ALPS|ITE8|WCOM|ASUE"
CANDIDATE_DRIVERS="i2c_hid_acpi i2c_hid"
LOG_TAG="fix-touchpad"

log() { logger -t "$LOG_TAG" "$1"; echo "$1"; }

touchpad_present() {
    # Vrai si un device d'entrée type touchpad/mouse est actif
    grep -qiE "touchpad|synaptics|elan|mouse" /proc/bus/input/devices 2>/dev/null
}

# --- 1. Détection ACPI HID ---
ACPI_HID=""
for dev in /sys/bus/acpi/devices/*; do
    [ -e "$dev/hid" ] || continue
    hid=$(cat "$dev/hid" 2>/dev/null || true)
    if echo "$hid" | grep -qiE "$KNOWN_HID_PATTERNS"; then
        ACPI_HID="$hid"
        break
    fi
done

# --- 2. Correspondance i2c + driver actuel (si existant) ---
DRIVER_NAME=""
DEVICE_ID=""

if [ -n "$ACPI_HID" ]; then
    for dev in /sys/bus/i2c/devices/i2c-*; do
        [ -e "$dev/modalias" ] || continue
        modalias=$(cat "$dev/modalias" 2>/dev/null || true)
        if echo "$modalias" | grep -qi "$ACPI_HID"; then
            DEVICE_ID="$(basename "$dev")"
            [ -e "$dev/driver" ] && DRIVER_NAME="$(basename "$(readlink -f "$dev/driver")")"
            break
        fi
    done
fi

# Fallback générique si pas de correspondance ACPI
if [ -z "$DEVICE_ID" ]; then
    for drv in $CANDIDATE_DRIVERS; do
        [ -d "/sys/bus/i2c/drivers/$drv" ] || continue
        for dev in /sys/bus/i2c/drivers/$drv/i2c-*; do
            [ -e "$dev" ] || continue
            DRIVER_NAME="$drv"
            DEVICE_ID="$(basename "$dev")"
            break 2
        done
    done
fi

FIXED=0

# --- 3a. Cas : driver déjà attaché -> rebind (unbind puis bind) ---
if [ -n "$DEVICE_ID" ] && [ -n "$DRIVER_NAME" ]; then
    log "Device $DEVICE_ID attaché à $DRIVER_NAME -> rebind."
    echo "$DEVICE_ID" > "/sys/bus/i2c/drivers/$DRIVER_NAME/unbind" 2>/dev/null || true
    sleep 1
    echo "$DEVICE_ID" > "/sys/bus/i2c/drivers/$DRIVER_NAME/bind" 2>/dev/null || true
    sleep 1
    touchpad_present && FIXED=1
fi

# --- 3b. Cas : device trouvé mais AUCUN driver attaché -> bind forcé ---
if [ "$FIXED" -eq 0 ] && [ -n "$DEVICE_ID" ] && [ -z "$DRIVER_NAME" ]; then
    log "Device $DEVICE_ID sans driver -> tentative de bind forcé."
    for drv in $CANDIDATE_DRIVERS; do
        modprobe "$drv" 2>/dev/null || true
        if [ -e "/sys/bus/i2c/drivers/$drv/bind" ]; then
            echo "$DEVICE_ID" > "/sys/bus/i2c/drivers/$drv/bind" 2>/dev/null || true
            sleep 1
            if touchpad_present; then
                FIXED=1
                log "Bind réussi avec $drv."
                break
            fi
        fi
    done
fi

# --- 3c. Cas : rien trouvé du tout -> re-déclenche une énumération i2c/acpi ---
if [ "$FIXED" -eq 0 ] && [ -z "$DEVICE_ID" ]; then
    log "Aucun device i2c-hid identifié. Nouvelle tentative après rescan udev."
    udevadm trigger --action=add 2>/dev/null || true
    sleep 1
    touchpad_present && FIXED=1
fi

# --- 4. Escalade : si toujours pas corrigé, cycle de veille réel ---
if [ "$FIXED" -eq 0 ]; then
    log "Correctif ciblé insuffisant -> escalade vers cycle de veille réel (rtcwake)."
    if command -v rtcwake >/dev/null 2>&1; then
        rtcwake -m mem -s 2 2>/dev/null || true
        sleep 1
        touchpad_present && FIXED=1
    fi
fi

if [ "$FIXED" -eq 1 ]; then
    log "Touchpad/souris détecté avec succès."
else
    log "Échec : touchpad toujours non détecté après toutes les tentatives."
fi

exit 0
ENGINE

chmod +x "$APPLY_SCRIPT"
echo "    ✅ Script moteur installé."
echo

# --- 2. Service systemd au démarrage ---
echo "[2/3] Installation des déclencheurs automatiques (boot + réveil)..."

cat > /etc/systemd/system/fix-touchpad.service <<EOF
[Unit]
Description=Correction automatique touchpad/souris i2c-hid (Lenovo A475)
After=multi-user.target graphical.target

[Service]
Type=oneshot
ExecStart=$APPLY_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable fix-touchpad.service >/dev/null 2>&1
echo "    ✅ Service au démarrage : fix-touchpad.service"

# Hook systemd-sleep : rejoue le correctif après CHAQUE réveil de veille
cat > /usr/lib/systemd/system-sleep/fix-touchpad-resume <<EOF
#!/bin/sh
if [ "\$1" = "post" ]; then
    $APPLY_SCRIPT
fi
EOF
chmod +x /usr/lib/systemd/system-sleep/fix-touchpad-resume
echo "    ✅ Hook post-réveil : /usr/lib/systemd/system-sleep/fix-touchpad-resume"
echo

# --- 3. Exécution immédiate + résumé ---
echo "[3/3] Application immédiate du correctif..."
echo "------------------------------------------------------"
"$APPLY_SCRIPT"
echo "------------------------------------------------------"
echo
echo "======================================================"
echo "  Terminé. Le correctif s'applique désormais tout seul :"
echo "    - à chaque démarrage"
echo "    - à chaque réveil de mise en veille"
echo "    - avec vérification et escalade automatique si besoin"
echo
echo "  Journal des exécutions : journalctl -t fix-touchpad"
echo "======================================================"
