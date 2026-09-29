#!/bin/bash

echo
echo "========== PAQUETS / MISES A JOUR =========="
echo

# ==========================================================
# 41 - CM-10 - Provenance de Nginx
# ==========================================================

if ! command -v dpkg-query >/dev/null 2>&1 ||
   ! command -v apt-cache >/dev/null 2>&1; then

    fail "41 | CM-10 | APT/dpkg indisponible"

elif ! dpkg-query -W nginx >/dev/null 2>&1; then

    fail "41 | CM-10 | Nginx absent"

else

    POLICY="$(apt-cache policy nginx 2>/dev/null)"
    REPO_OK=0

    for repo in $ALLOWED_REPOSITORIES; do
        if echo "$POLICY" | grep -Fq "$repo"; then
            REPO_OK=1
            break
        fi
    done

    if [ "$REPO_OK" -eq 1 ]; then
        pass "41 | CM-10 | Nginx provient d'un dépôt autorisé"
    else
        fail "41 | CM-10 | Provenance de Nginx non autorisée ou non démontrée"
    fi
fi


# ==========================================================
# 42 - SI-2 - Nginx à jour
# ==========================================================

if ! command -v apt >/dev/null 2>&1 ||
   ! command -v dpkg-query >/dev/null 2>&1; then

    fail "42 | SI-2 | APT/dpkg indisponible"

elif ! dpkg-query -W nginx >/dev/null 2>&1; then

    fail "42 | SI-2 | Nginx absent"

elif apt list --upgradable 2>/dev/null |
     grep -qE '^nginx(/|-)'; then

    fail "42 | SI-2 | Mise à jour Nginx disponible"

else

    VERSION="$(dpkg-query -W -f='${Version}' nginx 2>/dev/null)"
    pass "42 | SI-2 | Nginx à jour : $VERSION"
fi


# ==========================================================
# 43 - SI-2 - OpenSSL à jour
# ==========================================================

if ! command -v apt >/dev/null 2>&1 ||
   ! command -v dpkg-query >/dev/null 2>&1; then

    fail "43 | SI-2 | APT/dpkg indisponible"

elif ! dpkg-query -W openssl >/dev/null 2>&1; then

    fail "43 | SI-2 | OpenSSL absent"

elif apt list --upgradable 2>/dev/null |
     grep -q '^openssl/'; then

    fail "43 | SI-2 | Mise à jour OpenSSL disponible"

else

    VERSION="$(openssl version 2>/dev/null)"
    pass "43 | SI-2 | OpenSSL à jour : $VERSION"
fi


# ==========================================================
# 44 - CM-7 - Modules dynamiques Nginx
# ==========================================================

if ! command -v nginx >/dev/null 2>&1; then

    fail "44 | CM-7 | Nginx absent"

else

    LOADED_MODULES="$(
        nginx -T 2>/dev/null |
        awk '
            $1 == "load_module" {
                gsub(";", "", $2)
                print $2
            }
        '
    )"

    if [ -z "$LOADED_MODULES" ]; then
        pass "44 | CM-7 | Aucun module Nginx dynamique supplémentaire chargé"
    else
        fail "44 | CM-7 | Modules Nginx dynamiques détectés : $(echo "$LOADED_MODULES" | xargs)"
    fi
fi


# ==========================================================
# 45 - SI-2 - Mises à jour Debian
# ==========================================================

if ! command -v apt >/dev/null 2>&1; then

    fail "45 | SI-2 | APT indisponible"

else

    UPDATES="$(
        apt list --upgradable 2>/dev/null |
        tail -n +2
    )"

    if [ -z "$UPDATES" ]; then
        pass "45 | SI-2 | Aucun paquet à mettre à jour"
    else
        fail "45 | SI-2 | Des mises à jour système sont disponibles"
    fi
fi


# ==========================================================
# 46 - CM-10 - Dépôts APT autorisés
# ==========================================================

if [ ! -d /etc/apt ]; then

    fail "46 | CM-10 | Configuration APT absente"

else

    REPO_URLS="$(
        {
            grep -RhE '^[[:space:]]*deb[[:space:]]+' \
                /etc/apt/sources.list \
                /etc/apt/sources.list.d/ \
                2>/dev/null |
                awk '{print $2}'

            grep -RhE '^[[:space:]]*URIs:[[:space:]]+' \
                /etc/apt/sources.list.d/ \
                2>/dev/null |
                awk '{for (i=2; i<=NF; i++) print $i}'
        } |
        sort -u
    )"

    BAD_REPOS=""

    while IFS= read -r url; do

        [ -z "$url" ] && continue

        ALLOWED=0

        for repo in $ALLOWED_REPOSITORIES; do
            if echo "$url" | grep -Fq "$repo"; then
                ALLOWED=1
                break
            fi
        done

        if [ "$ALLOWED" -eq 0 ]; then
            BAD_REPOS="$BAD_REPOS $url"
        fi

    done <<< "$REPO_URLS"

    if [ -z "$REPO_URLS" ]; then
        fail "46 | CM-10 | Aucun dépôt APT détecté"
    elif [ -z "$BAD_REPOS" ]; then
        pass "46 | CM-10 | Tous les dépôts APT sont autorisés"
    else
        fail "46 | CM-10 | Dépôts non autorisés :$BAD_REPOS"
    fi
fi


# ==========================================================
# 47 - CM-6 - Paquets bloqués
# ==========================================================

if ! command -v apt-mark >/dev/null 2>&1; then

    fail "47 | CM-6 | apt-mark indisponible"

else

    HELD="$(
        apt-mark showhold 2>/dev/null |
        xargs
    )"

    if [ "$ALLOW_HELD_PACKAGES" = "no" ]; then

        if [ -z "$HELD" ]; then
            pass "47 | CM-6 | Aucun paquet bloqué"
        else
            fail "47 | CM-6 | Paquets bloqués : $HELD"
        fi

    else
        pass "47 | CM-6 | La baseline autorise les paquets bloqués"
    fi
fi


# ==========================================================
# 48 - CM-7 - Paquets interdits
# ==========================================================

BAD_PACKAGES=""

if ! command -v dpkg-query >/dev/null 2>&1; then

    fail "48 | CM-7 | dpkg-query indisponible"

else

    for package in $FORBIDDEN_PACKAGES; do

        STATUS="$(
            dpkg-query \
            -W \
            -f='${db:Status-Status}' \
            "$package" 2>/dev/null
        )"

        if [ "$STATUS" = "installed" ]; then
            BAD_PACKAGES="$BAD_PACKAGES $package"
        fi

    done

    if [ -z "$BAD_PACKAGES" ]; then
        pass "48 | CM-7 | Aucun paquet explicitement interdit installé"
    else
        fail "48 | CM-7 | Paquets interdits installés :$BAD_PACKAGES"
    fi
fi


# ==========================================================
# 49 - SI-2 - unattended-upgrades
# ==========================================================

if [ "$REQUIRE_AUTO_UPDATES" != "yes" ]; then

    pass "49 | SI-2 | Mises à jour automatiques non exigées"

elif ! command -v dpkg-query >/dev/null 2>&1; then

    fail "49 | SI-2 | dpkg-query indisponible"

elif ! dpkg-query -W unattended-upgrades >/dev/null 2>&1; then

    fail "49 | SI-2 | unattended-upgrades absent"

elif grep -RhEq \
     'APT::Periodic::Unattended-Upgrade[[:space:]]+"1"' \
     /etc/apt/apt.conf.d/ 2>/dev/null; then

    pass "49 | SI-2 | Mises à jour automatiques activées"

else
    fail "49 | SI-2 | unattended-upgrades non activé"
fi


# ==========================================================
# 50 - SA-22 - Composants obligatoires présents
# ==========================================================

MISSING_PACKAGES=""

if ! command -v dpkg-query >/dev/null 2>&1; then

    fail "50 | SA-22 | dpkg-query indisponible"

else

    for package in $REQUIRED_PACKAGES; do

        STATUS="$(
            dpkg-query \
            -W \
            -f='${db:Status-Status}' \
            "$package" 2>/dev/null
        )"

        if [ "$STATUS" != "installed" ]; then
            MISSING_PACKAGES="$MISSING_PACKAGES $package"
        fi

    done

    if [ -z "$MISSING_PACKAGES" ]; then
        pass "50 | SA-22 | Tous les composants obligatoires sont installés"
    else
        fail "50 | SA-22 | Composants obligatoires absents :$MISSING_PACKAGES"
    fi
fi