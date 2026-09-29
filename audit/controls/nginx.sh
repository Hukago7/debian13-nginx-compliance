#!/bin/bash

echo
echo "========== NGINX / TLS / SERVICES =========="
echo

# ==========================================================
# 31 - CM-7 - Service Nginx actif
# ==========================================================

if systemctl is-active --quiet nginx 2>/dev/null; then
    pass "31 | CM-7 | Service Nginx actif"
else
    fail "31 | CM-7 | Service Nginx inactif ou absent"
fi


# ==========================================================
# 32 - CM-6 - Nginx activé au démarrage
# ==========================================================

if systemctl is-enabled --quiet nginx 2>/dev/null; then
    pass "32 | CM-6 | Nginx activé au démarrage"
else
    fail "32 | CM-6 | Nginx non activé au démarrage"
fi


# ==========================================================
# 33 - CM-6 - Validité configuration Nginx
# ==========================================================

if ! command -v nginx >/dev/null 2>&1; then
    fail "33 | CM-6 | Nginx absent"
elif nginx -t >/dev/null 2>&1; then
    pass "33 | CM-6 | Configuration Nginx valide"
else
    fail "33 | CM-6 | Configuration Nginx invalide"
fi


# ==========================================================
# 34 - SI-2 - Mise à jour Nginx
# ==========================================================

if ! command -v dpkg-query >/dev/null 2>&1 ||
   ! command -v apt >/dev/null 2>&1; then

    fail "34 | SI-2 | Gestionnaire APT/dpkg indisponible"

elif ! dpkg-query -W nginx >/dev/null 2>&1; then

    fail "34 | SI-2 | Paquet Nginx absent"

else

    NGINX_UPDATE="$(
        apt list --upgradable 2>/dev/null |
        grep -E '^nginx(/|-)'
    )"

    if [ -z "$NGINX_UPDATE" ]; then
        VERSION="$(dpkg-query -W -f='${Version}' nginx 2>/dev/null)"
        pass "34 | SI-2 | Nginx à jour : $VERSION"
    else
        fail "34 | SI-2 | Mise à jour Nginx disponible"
    fi
fi


# ==========================================================
# 35 - AC-6 - Utilisateur Nginx
# ==========================================================

if ! command -v nginx >/dev/null 2>&1; then

    fail "35 | AC-6 | Nginx absent"

else

    DETECTED_USER="$(
        nginx -T 2>/dev/null |
        awk '
            $1 == "user" {
                gsub(";", "", $2)
                print $2
                exit
            }
        '
    )"

    if [ "$DETECTED_USER" = "$NGINX_USER" ]; then
        pass "35 | AC-6 | Utilisateur Nginx conforme : $DETECTED_USER"
    else
        fail "35 | AC-6 | Attendu : $NGINX_USER | Détecté : $DETECTED_USER"
    fi
fi


# ==========================================================
# 36 - TLS - Certificat présent et lisible
# ==========================================================

CERTIFICATE=""

if command -v nginx >/dev/null 2>&1; then
    CERTIFICATE="$(
        nginx -T 2>/dev/null |
        awk '
            $1 == "ssl_certificate" {
                gsub(";", "", $2)
                print $2
                exit
            }
        '
    )"
fi

if [ -z "$CERTIFICATE" ]; then

    fail "36 | TLS | Aucun certificat Nginx détecté"

elif [ ! -f "$CERTIFICATE" ]; then

    fail "36 | TLS | Certificat absent : $CERTIFICATE"

elif ! openssl x509 \
     -in "$CERTIFICATE" \
     -noout >/dev/null 2>&1; then

    fail "36 | TLS | Certificat X.509 invalide"

else
    pass "36 | TLS | Certificat X.509 présent et lisible : $CERTIFICATE"
fi


# ==========================================================
# 37 - SC-12 - Durée de validité du certificat
# ==========================================================

SECONDS_REQUIRED=$((CERT_MIN_DAYS * 86400))

if [ -z "$CERTIFICATE" ] ||
   [ ! -f "$CERTIFICATE" ]; then

    fail "37 | SC-12 | Aucun certificat à vérifier"

elif openssl x509 \
     -in "$CERTIFICATE" \
     -checkend "$SECONDS_REQUIRED" \
     -noout >/dev/null 2>&1; then

    EXPIRATION="$(
        openssl x509 \
        -in "$CERTIFICATE" \
        -noout \
        -enddate 2>/dev/null |
        cut -d= -f2-
    )"

    pass "37 | SC-12 | Certificat valide encore au moins ${CERT_MIN_DAYS} jours : $EXPIRATION"

else
    fail "37 | SC-12 | Certificat expiré ou expirant dans moins de ${CERT_MIN_DAYS} jours"
fi


# ==========================================================
# 38 - TLS - Protocoles autorisés
# ==========================================================

if ! command -v nginx >/dev/null 2>&1; then

    fail "38 | TLS | Nginx absent"

else

    TLS_LINE="$(
        nginx -T 2>/dev/null |
        awk '
            $1 == "ssl_protocols" {
                $1=""
                gsub(";", "")
                sub(/^[ \t]+/, "")
                print
                exit
            }
        '
    )"

    DETECTED_TLS="$(
        echo "$TLS_LINE" |
        tr ' ' '\n' |
        sed '/^$/d' |
        sort |
        xargs
    )"

    EXPECTED_TLS="$(
        echo "$TLS_ALLOWED_PROTOCOLS" |
        tr ' ' '\n' |
        sort |
        xargs
    )"

    if [ -n "$DETECTED_TLS" ] &&
       [ "$DETECTED_TLS" = "$EXPECTED_TLS" ]; then

        pass "38 | TLS | Protocoles conformes : $DETECTED_TLS"
    else
        fail "38 | TLS | Attendu : $EXPECTED_TLS | Détecté : $DETECTED_TLS"
    fi
fi


# ==========================================================
# 39 - TLS - Chiffrements faibles
# ==========================================================

if ! command -v nginx >/dev/null 2>&1; then

    fail "39 | TLS | Nginx absent"

else

    CIPHER_LINE="$(
        nginx -T 2>/dev/null |
        awk '
            $1 == "ssl_ciphers" {
                $1=""
                gsub(";", "")
                sub(/^[ \t]+/, "")
                print
                exit
            }
        '
    )"

    if [ -z "$CIPHER_LINE" ]; then

        fail "39 | TLS | ssl_ciphers non défini explicitement"

    else

        WEAK=""

        for cipher in $FORBIDDEN_CIPHERS; do
            if echo "$CIPHER_LINE" |
               grep -qi "$cipher"; then
                WEAK="$WEAK $cipher"
            fi
        done

        if [ -z "$WEAK" ]; then
            pass "39 | TLS | Aucun chiffrement explicitement interdit détecté"
        else
            fail "39 | TLS | Chiffrements interdits détectés :$WEAK"
        fi
    fi
fi


# ==========================================================
# 40 - CM-7 - Services interdits
# ==========================================================

if ! command -v systemctl >/dev/null 2>&1; then

    fail "40 | CM-7 | systemctl indisponible"

else

    BAD_SERVICES=""

    for service in $FORBIDDEN_SERVICES; do

        if systemctl is-active \
           --quiet "$service" 2>/dev/null; then

            BAD_SERVICES="$BAD_SERVICES $service"
        fi

    done

    if [ -z "$BAD_SERVICES" ]; then
        pass "40 | CM-7 | Aucun service explicitement interdit actif"
    else
        fail "40 | CM-7 | Services interdits actifs :$BAD_SERVICES"
    fi
fi
