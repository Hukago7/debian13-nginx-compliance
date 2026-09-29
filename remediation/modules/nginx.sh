#!/bin/bash

section "NGINX"

NGINX_SITE="/etc/nginx/sites-available/compliance"
NGINX_ENABLED="/etc/nginx/sites-enabled/compliance"
DEFAULT_SITE="/etc/nginx/sites-enabled/default"
WEB_INDEX="$WEB_ROOT/index.html"

# ==========================================================
# 31 - Service Nginx installé
# ==========================================================

if command -v nginx >/dev/null 2>&1; then
    ok "Nginx installé"
else
    error "Nginx n'est pas installé"
    return
fi


# ==========================================================
# 35 - Utilisateur worker
# ==========================================================

CURRENT_USER="$(
    awk '
        /^[[:space:]]*user[[:space:]]+/ {
            gsub(";", "", $2)
            print $2
            exit
        }
    ' /etc/nginx/nginx.conf
)"

if [ "$CURRENT_USER" = "$NGINX_USER" ]; then

    ok "Utilisateur Nginx conforme : $NGINX_USER"

else

    if grep -qE '^[[:space:]]*user[[:space:]]+' /etc/nginx/nginx.conf; then
        sed -i -E \
            "s|^[[:space:]]*user[[:space:]]+[^;]+;|user ${NGINX_USER};|" \
            /etc/nginx/nginx.conf
    else
        sed -i "1i user ${NGINX_USER};" /etc/nginx/nginx.conf
    fi

    changed "Utilisateur Nginx configuré : $NGINX_USER"
fi


# ==========================================================
# Répertoire Web
# ==========================================================

if [ ! -d "$WEB_ROOT" ]; then
    mkdir -p "$WEB_ROOT"
    changed "Création de $WEB_ROOT"
fi

EXPECTED_INDEX='<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Serveur conforme</title>
</head>
<body>
    <h1>Debian 13 / Nginx</h1>
    <p>Serveur opérationnel.</p>
</body>
</html>'

CURRENT_INDEX=""

if [ -f "$WEB_INDEX" ]; then
    CURRENT_INDEX="$(cat "$WEB_INDEX")"
fi

if [ "$CURRENT_INDEX" = "$EXPECTED_INDEX" ]; then
    ok "Page Web déjà conforme"
else
    printf '%s\n' "$EXPECTED_INDEX" > "$WEB_INDEX"
    changed "Création de la page Web"
fi


# ==========================================================
# Virtual host temporaire HTTP
#
# TLS sera ajouté par tls.sh.
# ==========================================================

EXPECTED_SITE="server {
    listen ${HTTP_PORT};
    listen [::]:${HTTP_PORT};

    server_name _;

    root ${WEB_ROOT};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}"

CURRENT_SITE=""

if [ -f "$NGINX_SITE" ]; then
    CURRENT_SITE="$(cat "$NGINX_SITE")"
fi

if [ "$CURRENT_SITE" = "$EXPECTED_SITE" ]; then

    ok "Virtual host Nginx déjà conforme"

else

    printf '%s\n' "$EXPECTED_SITE" > "$NGINX_SITE"
    changed "Configuration du virtual host Nginx"

fi


# ==========================================================
# Désactivation du site par défaut
# ==========================================================

if [ -e "$DEFAULT_SITE" ] || [ -L "$DEFAULT_SITE" ]; then

    rm -f "$DEFAULT_SITE"
    changed "Désactivation du site Nginx par défaut"

else
    ok "Site Nginx par défaut déjà désactivé"
fi


# ==========================================================
# Activation du site
# ==========================================================

if [ -L "$NGINX_ENABLED" ] &&
   [ "$(readlink -f "$NGINX_ENABLED")" = "$NGINX_SITE" ]; then

    ok "Site compliance déjà activé"

else

    rm -f "$NGINX_ENABLED"
    ln -s "$NGINX_SITE" "$NGINX_ENABLED"

    changed "Activation du site compliance"
fi


# ==========================================================
# 33 - Validation de la configuration
# ==========================================================

if nginx -t >/dev/null 2>&1; then

    ok "Configuration Nginx valide"

else

    error "Configuration Nginx invalide"
    nginx -t
    return

fi


# ==========================================================
# 32 - Activation au démarrage
# ==========================================================

if systemctl is-enabled --quiet "$NGINX_SERVICE" 2>/dev/null; then

    ok "Nginx déjà activé au démarrage"

else

    if systemctl enable "$NGINX_SERVICE" >/dev/null 2>&1; then
        changed "Activation de Nginx au démarrage"
    else
        error "Impossible d'activer Nginx"
    fi

fi


# ==========================================================
# 31 - Démarrage / rechargement
# ==========================================================

if systemctl is-active --quiet "$NGINX_SERVICE" 2>/dev/null; then

    if systemctl reload "$NGINX_SERVICE" >/dev/null 2>&1; then
        ok "Nginx actif et configuration rechargée"
    else
        error "Impossible de recharger Nginx"
    fi

else

    if systemctl start "$NGINX_SERVICE" >/dev/null 2>&1; then
        changed "Démarrage de Nginx"
    else
        error "Impossible de démarrer Nginx"
    fi

fi
