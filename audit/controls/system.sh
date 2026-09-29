#!/bin/bash

echo
echo "========== SYSTEME / NOYAU / COMPTES =========="
echo

# 01 - CM-8
# Debian 13 attendu
if grep -q 'VERSION_ID="13"' /etc/os-release 2>/dev/null; then
    pass "01 | CM-8 | Debian 13 détecté"
else
    fail "01 | CM-8 | Le système n'est pas Debian 13"
fi


# 02 - SI-2
# Vérification de la présence de mises à jour de sécurité/kernel
if apt list --upgradable 2>/dev/null | grep -qiE 'linux-image|linux-headers'; then
    fail "02 | SI-2 | Mise à jour du noyau disponible"
else
    pass "02 | SI-2 | Aucune mise à jour kernel détectée"
fi


# 03 - CM-8
ARCH="$(dpkg --print-architecture 2>/dev/null)"

if [ "$ARCH" = "amd64" ]; then
    pass "03 | CM-8 | Architecture amd64"
else
    fail "03 | CM-8 | Architecture détectée : $ARCH"
fi


# 04 - CM-8
HOST="$(hostnamectl --static 2>/dev/null)"

if [ -n "$HOST" ] && [ "$HOST" != "localhost" ]; then
    pass "04 | CM-8 | Hostname : $HOST"
else
    fail "04 | CM-8 | Hostname invalide"
fi


# 05 - CM-6
# Paramètres kernel au démarrage
CMDLINE="$(cat /proc/cmdline 2>/dev/null)"

if [ -n "$CMDLINE" ]; then
    pass "05 | CM-6 | Paramètres kernel accessibles : $CMDLINE"
else
    fail "05 | CM-6 | Impossible de lire /proc/cmdline"
fi


# 06 - SI-7
# Secure Boot
if command -v mokutil >/dev/null 2>&1; then

    if mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
        pass "06 | SI-7 | Secure Boot activé"
    else
        fail "06 | SI-7 | Secure Boot désactivé"
    fi

else
    manual "06 | SI-7 | mokutil absent : Secure Boot à vérifier manuellement"
fi


# 07 - CM-7
# Un script peut inventorier les modules,
# mais déterminer leur nécessité demande le contexte de la machine.
MODULE_COUNT="$(lsmod 2>/dev/null | tail -n +2 | wc -l)"

manual "07 | CM-7 | $MODULE_COUNT modules kernel chargés : nécessité à valider"


# 08 - AC-6
# Seul root doit normalement posséder UID 0
UID0_COUNT="$(awk -F: '$3 == 0 {print $1}' /etc/passwd | wc -l)"
UID0_USERS="$(awk -F: '$3 == 0 {print $1}' /etc/passwd | xargs)"

if [ "$UID0_COUNT" -eq 1 ] && [ "$UID0_USERS" = "root" ]; then
    pass "08 | AC-6 | Seul root possède UID 0"
else
    fail "08 | AC-6 | Comptes UID 0 détectés : $UID0_USERS"
fi


# 09 - AC-6
# Inventaire automatique, légitimité à contrôler humainement
SERVICE_ACCOUNTS="$(
    awk -F: '
        $3 < 1000 &&
        $1 != "root" &&
        $7 !~ /(nologin|false)$/ {
            print $1
        }
    ' /etc/passwd | xargs
)"

if [ -z "$SERVICE_ACCOUNTS" ]; then
    pass "09 | AC-6 | Aucun compte système avec shell interactif détecté"
else
    manual "09 | AC-6 | Comptes système avec shell : $SERVICE_ACCOUNTS"
fi


# 10 - IA-5
# La politique d'authentification dépend de plusieurs fichiers PAM.
# On vérifie automatiquement leur présence puis on garde une validation humaine.
if [ -f /etc/pam.d/common-password ] && [ -f /etc/login.defs ]; then
    manual "10 | IA-5 | Configuration PAM présente : politique à valider"
else
    fail "10 | IA-5 | Configuration d'authentification attendue absente"
fi