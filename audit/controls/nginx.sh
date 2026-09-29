#!/bin/bash

echo
echo "========== NGINX / TLS / SERVICES =========="
echo

# 31 - CM-7 - État du service Nginx
if systemctl is-active --quiet nginx 2>/dev/null; then
    pass "31 | CM-7 | Service Nginx actif"
else
    fail "31 | CM-7 | Service Nginx inactif ou absent"
fi


# 32 - CM-6 - Démarrage automatique
if systemctl is-enabled --quiet nginx 2>/dev/null; then
    pass "32 | CM-6 | Nginx activé au démarrage"
else
    fail "32 | CM-6 | Nginx non activé au démarrage"
fi


# 33 - CM-6 - Validité de la configuration
if command -v nginx >/dev/null 2>&1; then

    if nginx -t >/dev/null 2>&1; then
        pass "33 | CM-6 | Configuration Nginx valide"
    else
        fail "33 | CM-6 | Configuration Nginx invalide"
    fi

else
    fail "33 | CM-6 | Nginx non installé"
fi


# 34 - SI-2 - Version de Nginx
if command -v nginx >/dev/null 2>&1; then

    NGINX_VERSION="$(nginx -v 2>&1 | sed 's|nginx version: nginx/||')"

    if [ -n "$NGINX_VERSION" ]; then
        manual "34 | SI-2 | Version Nginx : $NGINX_VERSION - support à vérifier"
    else
        fail "34 | SI-2 | Impossible de déterminer la version de Nginx"
    fi

else
    fail "34 | SI-2 | Nginx non installé"
fi


# 35 - AC-6 - Utilisateur des workers Nginx
if command -v nginx >/dev/null 2>&1; then

    NGINX_USER="$(
        nginx -T 2>/dev/null |
        awk '$1 == "user" {
            gsub(";", "", $2)
            print $2
            exit
        }'
    )"

    if [ "$NGINX_USER" = "www-data" ]; then
        pass "35 | AC-6 | Workers Nginx exécutés avec www-data"
    elif [ -n "$NGINX_USER" ]; then
        manual "35 | AC-6 | Utilisateur Nginx détecté : $NGINX_USER"
    else
        fail "35 | AC-6 | Impossible de déterminer l'utilisateur Nginx"
    fi

else
    fail "35 | AC-6 | Nginx non installé"
fi


# 36 - CIS 4.1.2 - Certificat TLS
CERTIFICATE="$(
    nginx -T 2>/dev/null |
    awk '$1 == "ssl_certificate" {
        gsub(";", "", $2)
        print $2
        exit
    }'
)"

if [ -n "$CERTIFICATE" ] && [ -f "$CERTIFICATE" ]; then

    if openssl x509 -in "$CERTIFICATE" -noout >/dev/null 2>&1; then
        manual "36 | CIS 4.1.2 | Certificat TLS valide syntaxiquement : $CERTIFICATE"
    else
        fail "36 | CIS 4.1.2 | Certificat TLS illisible ou invalide"
    fi

else
    fail "36 | CIS 4.1.2 | Aucun certificat TLS Nginx détecté"
fi


# 37 - SC-12 - Validité temporelle du certificat
if [ -n "$CERTIFICATE" ] && [ -f "$CERTIFICATE" ]; then

    # 0 seconde = vérification qu'il n'est pas déjà expiré.
    if openssl x509 \
        -in "$CERTIFICATE" \
        -checkend 0 \
        -noout >/dev/null 2>&1; then

        EXPIRATION="$(
            openssl x509 \
            -in "$CERTIFICATE" \
            -noout \
            -enddate 2>/dev/null |
            cut -d= -f2-
        )"

        pass "37 | SC-12 | Certificat non expiré : $EXPIRATION"

    else
        fail "37 | SC-12 | Certificat TLS expiré"
    fi

else
    fail "37 | SC-12 | Aucun certificat à contrôler"
fi


# 38 - CIS 4.1.4 - Protocoles TLS
TLS_PROTOCOLS="$(
    nginx -T 2>/dev/null |
    grep -E '^[[:space:]]*ssl_protocols[[:space:]]' |
    head -n1
)"

if [ -z "$TLS_PROTOCOLS" ]; then

    fail "38 | CIS 4.1.4 | ssl_protocols non défini explicitement"

elif echo "$TLS_PROTOCOLS" |
     grep -qE 'SSLv2|SSLv3|TLSv1([^.]|$)|TLSv1\.1'; then

    fail "38 | CIS 4.1.4 | Protocole TLS obsolète autorisé : $TLS_PROTOCOLS"

elif echo "$TLS_PROTOCOLS" |
     grep -q 'TLSv1.2'; then

    pass "38 | CIS 4.1.4 | Protocoles TLS modernes configurés : $TLS_PROTOCOLS"

else
    manual "38 | CIS 4.1.4 | Configuration TLS à valider : $TLS_PROTOCOLS"
fi


# 39 - CIS 4.1.5 - Suites cryptographiques
CIPHERS="$(
    nginx -T 2>/dev/null |
    grep -E '^[[:space:]]*ssl_ciphers[[:space:]]' |
    head -n1
)"

if [ -n "$CIPHERS" ]; then

    # On peut détecter quelques familles faibles automatiquement,
    # mais une validation complète sera faite avec testssl.sh.
    if echo "$CIPHERS" |
       grep -qiE 'RC4|3DES|DES|NULL|EXPORT|MD5'; then

        fail "39 | CIS 4.1.5 | Suite cryptographique faible détectée"

    else
        manual "39 | CIS 4.1.5 | Ciphers configurés - validation testssl.sh requise"
    fi

else
    manual "39 | CIS 4.1.5 | ssl_ciphers non défini - validation testssl.sh requise"
fi


# 40 - CM-7 - Services inutiles
if command -v systemctl >/dev/null 2>&1; then

    SERVICES="$(
        systemctl list-units \
        --type=service \
        --state=running \
        --no-legend \
        --no-pager 2>/dev/null |
        awk '{print $1}' |
        xargs
    )"

    if [ -n "$SERVICES" ]; then
        manual "40 | CM-7 | Services actifs détectés : nécessité à valider"
    else
        fail "40 | CM-7 | Impossible d'inventorier les services actifs"
    fi

else
    fail "40 | CM-7 | systemctl indisponible"
fi
