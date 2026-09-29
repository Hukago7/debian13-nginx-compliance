#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_FILE="$PROJECT_DIR/config/baseline.conf"

if [ ! -f "$BASELINE_FILE" ]; then
    echo "[ERROR] Baseline introuvable : $BASELINE_FILE"
    exit 1
fi

source "$BASELINE_FILE"

PASS=0
FAIL=0
MANUAL=0

pass() {
    echo -e "[PASS] $1"
    ((PASS++))
}

fail() {
    echo -e "[FAIL] $1"
    ((FAIL++))
}

manual() {
    echo -e "[MANUAL] $1"
    ((MANUAL++))
}

export -f pass fail manual
export PASS FAIL MANUAL

echo "=================================================="
echo " AUDIT DE CONFORMITE DEBIAN 13 / NGINX"
echo "=================================================="
echo

source "$SCRIPT_DIR/controls/system.sh"
source "$SCRIPT_DIR/controls/network.sh"
source "$SCRIPT_DIR/controls/filesystem.sh"
source "$SCRIPT_DIR/controls/nginx.sh"
source "$SCRIPT_DIR/controls/packages.sh"

TOTAL=$((PASS + FAIL + MANUAL))

echo
echo "=================================================="
echo " RESULTAT"
echo "=================================================="
echo "PASS   : $PASS"
echo "FAIL   : $FAIL"
echo "MANUAL : $MANUAL"
echo "TOTAL  : $TOTAL / 50"
echo "=================================================="