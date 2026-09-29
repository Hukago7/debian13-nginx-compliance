#!/bin/bash

section "SYSTEME / NOYAU / COMPTES"

# ==========================================================
# 01 / 03 - Vérification des prérequis
# ==========================================================

OS_ID=""
OS_VERSION=""

if [ -f /etc/os-release ]; then
    OS_ID="$(. /etc/os-release && echo "$ID")"
    OS_VERSION="$(. /etc/os-release && echo "$VERSION_ID")"
fi

if [ "$OS_ID" = "$EXPECTED_OS" ] &&
   [ "$OS_VERSION" = "$EXPECTED_VERSION" ]; then
    ok "Système cible conforme : $OS_ID $OS_VERSION"
else
    error "Système attendu : $EXPECTED_OS $EXPECTED_VERSION | détecté : $OS_ID $OS_VERSION"
fi

if command -v dpkg >/dev/null 2>&1; then
    ARCH="$(dpkg --print-architecture 2>/dev/null)"
else
    ARCH="$(uname -m)"
fi

if [ "$ARCH" = "$EXPECTED_ARCH" ]; then
    ok "Architecture conforme : $ARCH"
else
    error "Architecture attendue : $EXPECTED_ARCH | détectée : $ARCH"
fi


# ==========================================================
# 04 - Hostname
# ==========================================================
# On vérifie seulement ici : aucun hostname précis n'est encore
# imposé par notre baseline.

HOST="$(hostname 2>/dev/null)"

if [ -n "$HOST" ] &&
   [ "$HOST" != "localhost" ] &&
   [ "$HOST" != "(none)" ]; then
    ok "Hostname valide : $HOST"
else
    error "Hostname invalide"
fi


# ==========================================================
# 05 / 14 - Paramètres sysctl
# ==========================================================

SYSCTL_FILE="/etc/sysctl.d/99-compliance.conf"

EXPECTED_SYSCTL='net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.ip_forward = 0'

CURRENT_SYSCTL=""

if [ -f "$SYSCTL_FILE" ]; then
    CURRENT_SYSCTL="$(cat "$SYSCTL_FILE")"
fi

if [ "$CURRENT_SYSCTL" = "$EXPECTED_SYSCTL" ]; then
    ok "Configuration sysctl persistante déjà conforme"
else
    printf '%s\n' "$EXPECTED_SYSCTL" > "$SYSCTL_FILE"

    if sysctl --system >/dev/null 2>&1; then
        changed "Durcissement des paramètres sysctl"
    else
        error "Impossible d'appliquer les paramètres sysctl"
    fi
fi


# ==========================================================
# 06 - Secure Boot
# ==========================================================

if command -v mokutil >/dev/null 2>&1; then

    if mokutil --sb-state 2>/dev/null |
       grep -qi "SecureBoot enabled"; then
        ok "Secure Boot activé"
    else
        error "Secure Boot désactivé : remédiation firmware nécessaire"
    fi

else
    error "mokutil absent : état Secure Boot non vérifiable"
fi


# ==========================================================
# 07 - Modules kernel interdits
# ==========================================================

MODPROBE_FILE="/etc/modprobe.d/compliance-blacklist.conf"

EXPECTED_MODULE_CONFIG=""

for module in $FORBIDDEN_MODULES; do
    EXPECTED_MODULE_CONFIG="${EXPECTED_MODULE_CONFIG}install ${module} /bin/false
blacklist ${module}
"
done

EXPECTED_MODULE_CONFIG="${EXPECTED_MODULE_CONFIG%$'\n'}"

CURRENT_MODULE_CONFIG=""

if [ -f "$MODPROBE_FILE" ]; then
    CURRENT_MODULE_CONFIG="$(cat "$MODPROBE_FILE")"
fi

if [ "$CURRENT_MODULE_CONFIG" = "$EXPECTED_MODULE_CONFIG" ]; then

    ok "Blacklist des modules kernel déjà conforme"

else

    printf '%s\n' "$EXPECTED_MODULE_CONFIG" > "$MODPROBE_FILE"
    changed "Configuration de la blacklist des modules kernel"

fi

# Tentative de déchargement si un module interdit est actuellement chargé.
for module in $FORBIDDEN_MODULES; do

    MODULE_NAME="${module//-/_}"

    if lsmod 2>/dev/null |
       awk '{print $1}' |
       grep -qx "$MODULE_NAME"; then

        if modprobe -r "$module" >/dev/null 2>&1; then
            changed "Déchargement du module kernel interdit : $module"
        else
            error "Module $module chargé mais impossible à décharger immédiatement"
        fi

    fi

done


# ==========================================================
# 08 - Comptes UID 0
# ==========================================================

UNAUTHORIZED_UID0="$(
    awk -F: '$3 == 0 {print $1}' /etc/passwd |
    while IFS= read -r user; do

        case " $ALLOWED_UID0_USERS " in
            *" $user "*) ;;
            *) echo "$user" ;;
        esac

    done
)"

if [ -z "$UNAUTHORIZED_UID0" ]; then

    ok "Aucun compte UID 0 non autorisé"

else

    # On ne supprime jamais automatiquement un compte.
    # On retire seulement son UID privilégié.
    while IFS= read -r user; do

        [ -z "$user" ] && continue

        NEW_UID="$(awk -F: '$3 >= 1000 {print $3}' /etc/passwd |
                   sort -n |
                   tail -n1)"

        if [ -z "$NEW_UID" ]; then
            NEW_UID=1000
        else
            NEW_UID=$((NEW_UID + 1))
        fi

        if usermod -u "$NEW_UID" "$user" >/dev/null 2>&1; then
            changed "Suppression de l'UID 0 du compte $user"
        else
            error "Impossible de modifier l'UID du compte $user"
        fi

    done <<< "$UNAUTHORIZED_UID0"

fi


# ==========================================================
# 09 - Comptes système avec shell interactif
# ==========================================================

BAD_SERVICE_ACCOUNTS="$(
    awk -F: '
        $3 < 1000 &&
        $1 != "root" &&
        $7 ~ /(bash|sh|dash|zsh|ksh)$/ {
            print $1
        }
    ' /etc/passwd
)"

if [ -z "$BAD_SERVICE_ACCOUNTS" ]; then

    ok "Comptes système non interactifs"

else

    while IFS= read -r user; do

        [ -z "$user" ] && continue

        if usermod -s /usr/sbin/nologin "$user" >/dev/null 2>&1; then
            changed "Shell interactif désactivé pour $user"
        else
            error "Impossible de modifier le shell de $user"
        fi

    done <<< "$BAD_SERVICE_ACCOUNTS"

fi


# ==========================================================
# 10 - Politique d'expiration des mots de passe
# ==========================================================

LOGIN_DEFS="/etc/login.defs"

set_login_def() {

    KEY="$1"
    VALUE="$2"

    CURRENT="$(
        awk -v key="$KEY" '$1 == key {print $2}' "$LOGIN_DEFS" |
        tail -n1
    )"

    if [ "$CURRENT" = "$VALUE" ]; then
        ok "$KEY déjà conforme : $VALUE"
        return
    fi

    if grep -qE "^[[:space:]]*${KEY}[[:space:]]+" "$LOGIN_DEFS"; then
        sed -i -E \
            "s|^[[:space:]]*${KEY}[[:space:]]+.*|${KEY}   ${VALUE}|" \
            "$LOGIN_DEFS"
    else
        printf '%s   %s\n' "$KEY" "$VALUE" >> "$LOGIN_DEFS"
    fi

    changed "$KEY configuré à $VALUE"
}

if [ -f "$LOGIN_DEFS" ]; then

    set_login_def "PASS_MAX_DAYS" "365"
    set_login_def "PASS_MIN_DAYS" "1"
    set_login_def "PASS_WARN_AGE" "7"

else
    error "$LOGIN_DEFS absent"
fi
