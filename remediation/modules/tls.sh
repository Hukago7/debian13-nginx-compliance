#!/bin/bash

section "TLS"

mkdir -p "$TLS_CERT_DIR"
chmod 700 "$TLS_CERT_DIR"

# ==========================================================
# CA locale
# ==========================================================

if [ -f "$TLS_CA_FILE" ] &&
   [ -f "$TLS_CA_KEY" ] &&
   openssl x509 -in "$TLS_CA_FILE" -noout >/dev/null 2>&1; then

    ok "CA locale déjà présente"

else

    rm -f "$TLS_CA_FILE" "$TLS_CA_KEY"

    if openssl req \
        -x509 \
        -newkey rsa:4096 \
        -sha256 \
        -nodes \
        -days 3650 \
        -subj "/CN=Debian13 Compliance Local CA" \
        -keyout "$TLS_CA_KEY" \
        -out "$TLS_CA_FILE" \
        >/dev/null 2>&1; then

        changed "Création de la CA locale"

    else
        error "Impossible de créer la CA locale"
        return
    fi
fi

chmod 600 "$TLS_CA_KEY"
chmod 644 "$TLS_CA_FILE"


# ==========================================================
# Certificat serveur
# ==========================================================

CERT_VALID="no"

if [ -f "$TLS_CERT_FILE" ] &&
   [ -f "$TLS_KEY_FILE" ]; then

    if openssl x509 \
        -checkend "$((CERT_MIN_DAYS * 86400))" \
        -noout \
        -in "$TLS_CERT_FILE" >/dev/null 2>&1; then

        CERT_VALID="yes"
    fi
fi

if [ "$CERT_VALID" = "yes" ]; then

    ok "Certificat serveur déjà valide"

else

    TMP_CSR="$(mktemp)"
    TMP_EXT="$(mktemp)"

    cat > "$TMP_EXT" <<EXT
subjectAltName=DNS:${TLS_CERT_CN},IP:127.0.0.1
extendedKeyUsage=serverAuth
keyUsage=digitalSignature,keyEncipherment
EXT

    openssl req \
        -new \
        -newkey rsa:2048 \
        -nodes \
        -subj "/CN=${TLS_CERT_CN}" \
        -keyout "$TLS_KEY_FILE" \
        -out "$TMP_CSR" \
        >/dev/null 2>&1

    if openssl x509 \
        -req \
        -in "$TMP_CSR" \
        -CA "$TLS_CA_FILE" \
        -CAkey "$TLS_CA_KEY" \
        -CAcreateserial \
        -days "$TLS_CERT_DAYS" \
        -sha256 \
        -extfile "$TMP_EXT" \
        -out "$TLS_CERT_FILE" \
        >/dev/null 2>&1; then

        changed "Création du certificat TLS serveur"

    else

        error "Impossible de créer le certificat TLS"
        rm -f "$TMP_CSR" "$TMP_EXT"
        return

    fi

    rm -f "$TMP_CSR" "$TMP_EXT"
fi

chmod 600 "$TLS_KEY_FILE"
chmod 644 "$TLS_CERT_FILE"


# ==========================================================
# Configuration HTTPS + redirection HTTP -> HTTPS
# ==========================================================

EXPECTED_SITE="server {
    listen ${HTTP_PORT};
    listen [::]:${HTTP_PORT};

    server_name _;

    return 301 https://\$host\$request_uri;
}

server {
    listen ${HTTPS_PORT} ssl;
    listen [::]:${HTTPS_PORT} ssl;

    server_name _;

    ssl_certificate ${TLS_CERT_FILE};
    ssl_certificate_key ${TLS_KEY_FILE};

    ssl_protocols ${TLS_ALLOWED_PROTOCOLS};
    ssl_ciphers HIGH:!aNULL:!MD5:!3DES:!RC4;

    root ${WEB_ROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}"

CURRENT_SITE="$(cat "$NGINX_SITE" 2>/dev/null)"

if [ "$CURRENT_SITE" = "$EXPECTED_SITE" ]; then

    ok "Configuration HTTPS déjà conforme"

else

    printf '%s\n' "$EXPECTED_SITE" > "$NGINX_SITE"
    changed "Configuration HTTPS et redirection HTTP"

fi


# ==========================================================
# Validation
# ==========================================================

if nginx -t >/dev/null 2>&1; then

    ok "Configuration TLS Nginx valide"

    if systemctl reload nginx >/dev/null 2>&1; then
        ok "Nginx rechargé"
    else
        error "Impossible de recharger Nginx"
    fi

else

    error "Configuration TLS Nginx invalide"
    nginx -t
fi
