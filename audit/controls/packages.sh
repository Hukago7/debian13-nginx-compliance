#!/bin/bash

echo
echo "========== PAQUETS / MISES A JOUR =========="
echo

# 41 - CM-10 - Installation et provenance de Nginx
if dpkg-query -W nginx >/dev/null 2>&1; then
    NGINX_SOURCE="$(apt-cache policy nginx 2>/dev/null | grep -A5 'Installed:' | grep -m1 'http' | xargs)"

    if [ -n "$NGINX_SOURCE" ]; then
        manual "41 | CM-10 | Nginx installé - provenance à valider : $NGINX_SOURCE"
    else
        manual "41 | CM-10 | Nginx installé - provenance du paquet à valider"
    fi
else
    fail "41 | CM-10 | Paquet Nginx absent"
fi


# 42 - SI-2 - Mise à jour de Nginx
if dpkg-query -W nginx >/dev/null 2>&1; then

    if apt list --upgradable 2>/dev/null |
       grep -q '^nginx/'; then

        fail "42 | SI-2 | Mise à jour Nginx disponible"
    else
        pass "42 | SI-2 | Aucune mise à jour Nginx détectée"
    fi

else
    fail "42 | SI-2 | Nginx non installé"
fi


# 43 - SI-2 - OpenSSL
if command -v openssl >/dev/null 2>&1; then

    OPENSSL_VERSION="$(openssl version 2>/dev/null)"

    if apt list --upgradable 2>/dev/null |
       grep -q '^openssl/'; then

        fail "43 | SI-2 | Mise à jour OpenSSL disponible : $OPENSSL_VERSION"
    else
        pass "43 | SI-2 | OpenSSL installé et aucune mise à jour détectée : $OPENSSL_VERSION"
    fi

else
    fail "43 | SI-2 | OpenSSL absent"
fi


# 44 - CM-7 - Modules Nginx
if command -v nginx >/dev/null 2>&1; then

    MODULES="$(nginx -V 2>&1 | grep -o -- '--with-[^ ]*\|--add-module=[^ ]*' | xargs)"

    if [ -n "$MODULES" ]; then
        manual "44 | CM-7 | Modules/options Nginx détectés : nécessité à valider"
    else
        manual "44 | CM-7 | Aucun module additionnel identifié automatiquement"
    fi

else
    fail "44 | CM-7 | Nginx absent"
fi


# 45 - SI-2 - Mises à jour de sécurité Debian
UPDATES="$(apt list --upgradable 2>/dev/null | tail -n +2)"

if [ -z "$UPDATES" ]; then
    pass "45 | SI-2 | Aucun paquet à mettre à jour"
else
    manual "45 | SI-2 | Mises à jour disponibles : analyse sécurité nécessaire"
fi


# 46 - CM-10 - Dépôts APT
REPOS="$(
    grep -RhE '^[[:space:]]*deb[[:space:]]|^[[:space:]]*URIs:' \
        /etc/apt/sources.list \
        /etc/apt/sources.list.d/ \
        2>/dev/null |
    xargs
)"

if [ -n "$REPOS" ]; then
    manual "46 | CM-10 | Dépôts APT détectés : provenance à valider"
else
    fail "46 | CM-10 | Aucun dépôt APT détecté"
fi


# 47 - CM-6 - Paquets bloqués
if command -v apt-mark >/dev/null 2>&1; then

    HELD="$(apt-mark showhold 2>/dev/null | xargs)"

    if [ -z "$HELD" ]; then
        pass "47 | CM-6 | Aucun paquet bloqué"
    else
        manual "47 | CM-6 | Paquets bloqués : $HELD"
    fi

else
    fail "47 | CM-6 | apt-mark indisponible"
fi


# 48 - CM-7 - Paquets inutiles
if command -v apt-get >/dev/null 2>&1; then

    AUTOREMOVE="$(
        apt-get -s autoremove 2>/dev/null |
        awk '/^Remv / {print $2}' |
        xargs
    )"

    if [ -z "$AUTOREMOVE" ]; then
        pass "48 | CM-7 | Aucun paquet supprimable automatiquement"
    else
        manual "48 | CM-7 | Paquets potentiellement inutiles : $AUTOREMOVE"
    fi

else
    fail "48 | CM-7 | apt-get indisponible"
fi


# 49 - SI-2 - Mises à jour automatiques
if dpkg-query -W unattended-upgrades >/dev/null 2>&1; then

    AUTO_UPDATES="$(
        grep -RhE \
        'APT::Periodic::Unattended-Upgrade[[:space:]]+"1"' \
        /etc/apt/apt.conf.d/ \
        2>/dev/null
    )"

    if [ -n "$AUTO_UPDATES" ]; then
        pass "49 | SI-2 | unattended-upgrades activé"
    else
        fail "49 | SI-2 | unattended-upgrades installé mais non activé"
    fi

else
    fail "49 | SI-2 | unattended-upgrades absent"
fi


# 50 - SA-22 - Composants supportés
if command -v nginx >/dev/null 2>&1 &&
   command -v openssl >/dev/null 2>&1; then

    NGINX_VERSION="$(nginx -v 2>&1)"
    OPENSSL_VERSION="$(openssl version 2>/dev/null)"

    manual "50 | SA-22 | Support à valider : $NGINX_VERSION / $OPENSSL_VERSION"

else
    fail "50 | SA-22 | Nginx ou OpenSSL absent"
fi
