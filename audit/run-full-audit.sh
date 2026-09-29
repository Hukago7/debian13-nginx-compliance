#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT_DIR="$SCRIPT_DIR/reports"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

mkdir -p "$REPORT_DIR"

echo "=================================================="
echo " AUDIT COMPLET DEBIAN 13 / NGINX"
echo "=================================================="
echo
echo "Rapports : $REPORT_DIR"
echo


# ==========================================================
# 1 - AUDIT CUSTOM - 50 CONTROLES
# ==========================================================

echo "========== 1/4 - AUDIT CUSTOM =========="

"$SCRIPT_DIR/audit.sh" \
    2>&1 |
    tee "$REPORT_DIR/custom-$TIMESTAMP.txt"

CUSTOM_EXIT=${PIPESTATUS[0]}

echo


# ==========================================================
# 2 - LYNIS
# ==========================================================

echo "========== 2/4 - LYNIS =========="

if command -v lynis >/dev/null 2>&1; then

    lynis audit system \
        --quick \
        --no-colors \
        2>&1 |
        tee "$REPORT_DIR/lynis-$TIMESTAMP.txt"

    LYNIS_EXIT=${PIPESTATUS[0]}

else
    echo "[SKIP] Lynis non installé"
    LYNIS_EXIT=127
fi

echo


# ==========================================================
# 3 - TRIVY
# ==========================================================

echo "========== 3/4 - TRIVY =========="

if command -v trivy >/dev/null 2>&1; then

    trivy rootfs \
        --scanners vuln \
        --pkg-types os \
        --severity HIGH,CRITICAL \
        --no-progress \
        / \
        2>&1 |
        tee "$REPORT_DIR/trivy-$TIMESTAMP.txt"

    TRIVY_EXIT=${PIPESTATUS[0]}

else
    echo "[SKIP] Trivy non installé"
    TRIVY_EXIT=127
fi

echo


# ==========================================================
# 4 - TESTSSL.SH
# ==========================================================

echo "========== 4/4 - TESTSSL.SH =========="

TESTSSL=""

if command -v testssl.sh >/dev/null 2>&1; then
    TESTSSL="$(command -v testssl.sh)"
elif command -v testssl >/dev/null 2>&1; then
    TESTSSL="$(command -v testssl)"
fi

if [ -n "$TESTSSL" ]; then

    "$TESTSSL" \
        --quiet \
        --warnings batch \
        https://127.0.0.1:443 \
        2>&1 |
        tee "$REPORT_DIR/testssl-$TIMESTAMP.txt"

    TESTSSL_EXIT=${PIPESTATUS[0]}

else
    echo "[SKIP] testssl.sh non installé"
    TESTSSL_EXIT=127
fi


# ==========================================================
# RESUME
# ==========================================================

echo
echo "=================================================="
echo " RESUME"
echo "=================================================="
echo "Audit custom : code $CUSTOM_EXIT"
echo "Lynis        : code $LYNIS_EXIT"
echo "Trivy        : code $TRIVY_EXIT"
echo "testssl.sh   : code $TESTSSL_EXIT"
echo
echo "Rapports enregistrés dans :"
echo "$REPORT_DIR"
echo "=================================================="

# Le résultat de conformité officiel reste celui des 50 contrôles.
exit "$CUSTOM_EXIT"
