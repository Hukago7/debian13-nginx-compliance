#!/bin/bash

echo
echo "========== SYSTEME / NOYAU / COMPTES =========="
echo

# ==========================================================
# 01 - CM-8 - Système d'exploitation
# ==========================================================

OS_ID=""
OS_VERSION=""

if [ -f /etc/os-release ]; then
    OS_ID="$(. /etc/os-release && echo "$ID")"
    OS_VERSION="$(. /etc/os-release && echo "$VERSION_ID")"
fi

if [ "$OS_ID" = "$EXPECTED_OS" ] &&
   [ "$OS_VERSION" = "$EXPECTED_VERSION" ]; then
    pass "01 | CM-8 | OS conforme : $OS_ID $OS_VERSION"
else
    fail "01 | CM-8 | Attendu : $EXPECTED_OS $EXPECTED_VERSION | Détecté : $OS_ID $OS_VERSION"
fi


# ==========================================================
# 02 - SI-2 - Mise à jour du noyau
# ==========================================================

if ! command -v apt >/dev/null 2>&1; then
    fail "02 | SI-2 | apt indisponible : conformité kernel impossible à démontrer"
else
    KERNEL_UPDATES="$(
        apt list --upgradable 2>/dev/null |
        grep -E '^linux-(image|headers)' || true
    )"

    if [ -z "$KERNEL_UPDATES" ]; then
        pass "02 | SI-2 | Aucune mise à jour kernel détectée"
    else
        fail "02 | SI-2 | Mise à jour kernel disponible"
    fi
fi


# ==========================================================
# 03 - CM-8 - Architecture
# ==========================================================

if command -v dpkg >/dev/null 2>&1; then
    ARCH="$(dpkg --print-architecture 2>/dev/null)"
else
    case "$(uname -m)" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *)       ARCH="$(uname -m)" ;;
    esac
fi

if [ "$ARCH" = "$EXPECTED_ARCH" ]; then
    pass "03 | CM-8 | Architecture conforme : $ARCH"
else
    fail "03 | CM-8 | Attendu : $EXPECTED_ARCH | Détecté : $ARCH"
fi


# ==========================================================
# 04 - CM-8 - Hostname
# ==========================================================

HOST="$(hostname 2>/dev/null)"

if [ -n "$HOST" ] &&
   [ "$HOST" != "localhost" ] &&
   [ "$HOST" != "(none)" ]; then
    pass "04 | CM-8 | Hostname valide : $HOST"
else
    fail "04 | CM-8 | Hostname invalide : $HOST"
fi


# ==========================================================
# 05 - CM-6 - Paramètres de sécurité kernel
# ==========================================================

KERNEL_OK=1
KERNEL_ERRORS=""

check_sysctl() {
    KEY="$1"
    EXPECTED="$2"

    VALUE="$(sysctl -n "$KEY" 2>/dev/null)"

    if [ "$VALUE" != "$EXPECTED" ]; then
        KERNEL_OK=0
        KERNEL_ERRORS="$KERNEL_ERRORS $KEY=$VALUE(attendu:$EXPECTED)"
    fi
}

check_sysctl "net.ipv4.conf.all.accept_redirects" "0"
check_sysctl "net.ipv4.conf.default.accept_redirects" "0"
check_sysctl "net.ipv4.conf.all.send_redirects" "0"
check_sysctl "net.ipv4.conf.default.send_redirects" "0"
check_sysctl "net.ipv4.conf.all.accept_source_route" "0"
check_sysctl "net.ipv4.conf.default.accept_source_route" "0"

if [ "$KERNEL_OK" -eq 1 ]; then
    pass "05 | CM-6 | Paramètres kernel de sécurité conformes"
else
    fail "05 | CM-6 | Paramètres kernel non conformes :$KERNEL_ERRORS"
fi


# ==========================================================
# 06 - SI-7 - Secure Boot
# ==========================================================

if ! command -v mokutil >/dev/null 2>&1; then
    fail "06 | SI-7 | mokutil absent : Secure Boot non démontré"
elif mokutil --sb-state 2>/dev/null |
     grep -qi "SecureBoot enabled"; then
    pass "06 | SI-7 | Secure Boot activé"
else
    fail "06 | SI-7 | Secure Boot désactivé"
fi


# ==========================================================
# 07 - CM-7 - Modules kernel dangereux
# ==========================================================

FORBIDDEN_MODULES="cramfs freevxfs hfs hfsplus jffs2 squashfs udf usb-storage"

LOADED_FORBIDDEN=""

for module in $FORBIDDEN_MODULES; do
    MODULE_NAME="${module//-/_}"

    if lsmod 2>/dev/null |
       awk '{print $1}' |
       grep -qx "$MODULE_NAME"; then
        LOADED_FORBIDDEN="$LOADED_FORBIDDEN $module"
    fi
done

if [ -z "$LOADED_FORBIDDEN" ]; then
    pass "07 | CM-7 | Aucun module kernel interdit chargé"
else
    fail "07 | CM-7 | Modules kernel interdits chargés :$LOADED_FORBIDDEN"
fi


# ==========================================================
# 08 - AC-6 - Comptes UID 0
# ==========================================================

UID0_USERS="$(
    awk -F: '$3 == 0 {print $1}' /etc/passwd |
    sort |
    xargs
)"

EXPECTED_UID0="$(
    echo "$ALLOWED_UID0_USERS" |
    tr ' ' '\n' |
    sort |
    xargs
)"

if [ "$UID0_USERS" = "$EXPECTED_UID0" ]; then
    pass "08 | AC-6 | Comptes UID 0 conformes : $UID0_USERS"
else
    fail "08 | AC-6 | Attendu : $EXPECTED_UID0 | Détecté : $UID0_USERS"
fi


# ==========================================================
# 09 - AC-6 - Comptes système interactifs
# ==========================================================

BAD_SERVICE_ACCOUNTS="$(
    awk -F: '
        $3 < 1000 &&
        $1 != "root" &&
        $7 !~ /(nologin|false)$/ {
            print $1
        }
    ' /etc/passwd |
    xargs
)"

if [ -z "$BAD_SERVICE_ACCOUNTS" ]; then
    pass "09 | AC-6 | Aucun compte système avec shell interactif"
else
    fail "09 | AC-6 | Comptes système interactifs : $BAD_SERVICE_ACCOUNTS"
fi


# ==========================================================
# 10 - IA-5 - Politique de mots de passe
# ==========================================================

LOGIN_DEFS="/etc/login.defs"

if [ ! -f "$LOGIN_DEFS" ]; then
    fail "10 | IA-5 | /etc/login.defs absent"
else
    PASS_MAX_DAYS="$(
        awk '$1 == "PASS_MAX_DAYS" {print $2}' "$LOGIN_DEFS" |
        tail -n1
    )"

    PASS_MIN_DAYS="$(
        awk '$1 == "PASS_MIN_DAYS" {print $2}' "$LOGIN_DEFS" |
        tail -n1
    )"

    PASS_WARN_AGE="$(
        awk '$1 == "PASS_WARN_AGE" {print $2}' "$LOGIN_DEFS" |
        tail -n1
    )"

    if [[ "$PASS_MAX_DAYS" =~ ^[0-9]+$ ]] &&
       [[ "$PASS_MIN_DAYS" =~ ^[0-9]+$ ]] &&
       [[ "$PASS_WARN_AGE" =~ ^[0-9]+$ ]] &&
       [ "$PASS_MAX_DAYS" -le 365 ] &&
       [ "$PASS_MIN_DAYS" -ge 1 ] &&
       [ "$PASS_WARN_AGE" -ge 7 ]; then

        pass "10 | IA-5 | Politique d'expiration conforme : max=${PASS_MAX_DAYS}j min=${PASS_MIN_DAYS}j avertissement=${PASS_WARN_AGE}j"
    else
        fail "10 | IA-5 | Politique d'expiration non conforme : max=$PASS_MAX_DAYS min=$PASS_MIN_DAYS avertissement=$PASS_WARN_AGE"
    fi
fi
EOF