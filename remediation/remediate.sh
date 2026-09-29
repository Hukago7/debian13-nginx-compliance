#!/bin/bash

# Ne pas utiliser "set -e" ici :
# certaines commandes de vérification peuvent retourner != 0 sans que
# cela doive interrompre toute la remédiation.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_FILE="$PROJECT_DIR/config/baseline.conf"

CHANGES=0
ERRORS=0

ok() {
    echo "[OK]      $1"
}

changed() {
    echo "[CHANGED] $1"
    ((CHANGES+=1))
}

error() {
    echo "[ERROR]   $1"
    ((ERRORS+=1))
}

section() {
    echo
    echo "=================================================="
    echo " $1"
    echo "=================================================="
}

# Root obligatoire
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Ce script doit être exécuté avec sudo/root."
    exit 1
fi

# Baseline obligatoire
if [ ! -f "$BASELINE_FILE" ]; then
    echo "[ERROR] Baseline introuvable : $BASELINE_FILE"
    exit 1
fi

source "$BASELINE_FILE"

export -f ok changed error section
export PROJECT_DIR BASELINE_FILE

echo "=================================================="
echo " REMEDIATION DEBIAN 13 / NGINX"
echo "=================================================="

source "$SCRIPT_DIR/modules/packages.sh"
source "$SCRIPT_DIR/modules/system.sh"
source "$SCRIPT_DIR/modules/filesystem.sh"
source "$SCRIPT_DIR/modules/network.sh"
source "$SCRIPT_DIR/modules/nginx.sh"
source "$SCRIPT_DIR/modules/tls.sh"
source "$SCRIPT_DIR/modules/services.sh"

echo
echo "=================================================="
echo " RESULTAT DE LA REMEDIATION"
echo "=================================================="
echo "Modifications : $CHANGES"
echo "Erreurs        : $ERRORS"
echo "=================================================="

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi

exit 0
