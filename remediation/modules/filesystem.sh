#!/bin/bash

section "SYSTEME DE FICHIERS / PERMISSIONS"

# ==========================================================
# 24 / 25 - Espace disque
# ==========================================================

ROOT_USAGE="$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')"

if [ "$ROOT_USAGE" -lt "$MAX_DISK_USAGE" ]; then
    ok "Utilisation de / conforme : ${ROOT_USAGE}%"
else
    error "Utilisation de / trop élevée : ${ROOT_USAGE}%"
fi

if [ -d /var/log ]; then
    LOG_USAGE="$(df -P /var/log | awk 'NR==2 {gsub("%","",$5); print $5}')"
    LOG_INODES="$(df -Pi /var/log | awk 'NR==2 {gsub("%","",$5); print $5}')"

    if [ "$LOG_USAGE" -lt "$MAX_DISK_USAGE" ] &&
       [ "$LOG_INODES" -lt "$MAX_INODE_USAGE" ]; then
        ok "/var/log conforme : disque ${LOG_USAGE}% / inodes ${LOG_INODES}%"
    else
        error "/var/log dépasse les seuils autorisés"
    fi
fi


# ==========================================================
# 26 - Permissions /etc/nginx
# ==========================================================

if [ -d "$NGINX_CONFIG_DIR" ]; then

    BAD_NGINX_PERMS="$(
        find "$NGINX_CONFIG_DIR" \
            \( ! -user root -o -perm /022 \) \
            -print 2>/dev/null
    )"

    if [ -z "$BAD_NGINX_PERMS" ]; then

        ok "Permissions de $NGINX_CONFIG_DIR conformes"

    else

        chown -R root:root "$NGINX_CONFIG_DIR"

        find "$NGINX_CONFIG_DIR" -type d \
            -exec chmod 755 {} \;

        find "$NGINX_CONFIG_DIR" -type f \
            -exec chmod 644 {} \;

        # Les clés privées seront resserrées juste après.
        if [ -f "$TLS_KEY_FILE" ]; then
            chmod 600 "$TLS_KEY_FILE"
        fi

        if [ -f "$TLS_CA_KEY" ]; then
            chmod 600 "$TLS_CA_KEY"
        fi

        changed "Correction des permissions de $NGINX_CONFIG_DIR"
    fi

else
    error "$NGINX_CONFIG_DIR absent"
fi


# ==========================================================
# 27 / 29 - Web root
# ==========================================================

if [ -d "$WEB_ROOT" ]; then

    BAD_WEB_PERMS="$(
        find "$WEB_ROOT" -perm /002 -print 2>/dev/null
    )"

    BAD_WEB_OWNERS="$(
        find "$WEB_ROOT" -printf '%u\n' 2>/dev/null |
        sort -u |
        while IFS= read -r owner; do
            case " $WEB_ALLOWED_OWNERS " in
                *" $owner "*) ;;
                *) echo "$owner" ;;
            esac
        done
    )"

    if [ -n "$BAD_WEB_PERMS" ]; then

        find "$WEB_ROOT" -perm /002 \
            -exec chmod o-w {} \;

        changed "Suppression des écritures world sur $WEB_ROOT"

    else
        ok "Aucun fichier world-writable dans $WEB_ROOT"
    fi

    if [ -n "$BAD_WEB_OWNERS" ]; then

        chown -R root:root "$WEB_ROOT"
        changed "Correction des propriétaires de $WEB_ROOT"

    else
        ok "Propriétaires de $WEB_ROOT conformes"
    fi

else
    error "$WEB_ROOT absent"
fi


# ==========================================================
# 28 - Clés privées TLS
# ==========================================================

for key in "$TLS_KEY_FILE" "$TLS_CA_KEY"; do

    if [ ! -f "$key" ]; then
        continue
    fi

    OWNER="$(stat -c '%U' "$key")"
    MODE="$(stat -c '%a' "$key")"

    if [ "$OWNER" = "root" ] && [ "$MODE" = "600" ]; then

        ok "Clé privée protégée : $key"

    else

        chown root:root "$key"
        chmod 600 "$key"

        changed "Permissions corrigées : $key"
    fi

done


# ==========================================================
# 30 - Validation fstab
# ==========================================================

if [ -f /etc/fstab ]; then

    if findmnt --verify --tab-file /etc/fstab >/dev/null 2>&1; then
        ok "/etc/fstab valide"
    else
        error "/etc/fstab contient une erreur"
    fi

else
    error "/etc/fstab absent"
fi


# ==========================================================
# 22 - Filesystems interdits
# ==========================================================

for fs in $FORBIDDEN_FILESYSTEMS; do

    if findmnt -t "$fs" >/dev/null 2>&1; then
        error "Filesystem interdit actuellement monté : $fs"
    else
        ok "Filesystem $fs non monté"
    fi

done
