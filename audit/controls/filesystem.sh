#!/bin/bash

echo
echo "========== STOCKAGE / PERMISSIONS =========="
echo

# 21 - CM-6 - Partitionnement
PARTITIONS="$(lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINTS 2>/dev/null)"

if [ -n "$PARTITIONS" ]; then
    manual "21 | CM-6 | Partitionnement détecté : validation nécessaire"
else
    fail "21 | CM-6 | Impossible d'obtenir le partitionnement"
fi


# 22 - CM-7 - Systèmes de fichiers
FILESYSTEMS="$(findmnt -rn -o FSTYPE 2>/dev/null | sort -u | xargs)"

if [ -n "$FILESYSTEMS" ]; then
    manual "22 | CM-7 | Systèmes de fichiers : $FILESYSTEMS"
else
    fail "22 | CM-7 | Impossible d'identifier les systèmes de fichiers"
fi


# 23 - CM-6 - Options de montage
MOUNTS="$(findmnt -rn -o TARGET,OPTIONS 2>/dev/null)"

if [ -n "$MOUNTS" ]; then
    manual "23 | CM-6 | Options de montage récupérées : validation nécessaire"
else
    fail "23 | CM-6 | Impossible de récupérer les options de montage"
fi


# 24 - AU-4 - Espace disque
ROOT_USAGE="$(df -P / 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"

if [[ "$ROOT_USAGE" =~ ^[0-9]+$ ]]; then
    if [ "$ROOT_USAGE" -lt 90 ]; then
        pass "24 | AU-4 | Utilisation de / : ${ROOT_USAGE}%"
    else
        fail "24 | AU-4 | Espace disque critique : ${ROOT_USAGE}%"
    fi
else
    fail "24 | AU-4 | Impossible de déterminer l'utilisation disque"
fi


# 25 - AU-4 - /var/log : espace et inodes
if [ -d /var/log ]; then

    LOG_USAGE="$(df -P /var/log 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"
    LOG_INODES="$(df -Pi /var/log 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}')"

    if [[ "$LOG_USAGE" =~ ^[0-9]+$ ]] &&
       [[ "$LOG_INODES" =~ ^[0-9]+$ ]] &&
       [ "$LOG_USAGE" -lt 90 ] &&
       [ "$LOG_INODES" -lt 90 ]; then

        pass "25 | AU-4 | /var/log : disque ${LOG_USAGE}% / inodes ${LOG_INODES}%"

    else
        fail "25 | AU-4 | /var/log proche de la saturation"
    fi

else
    fail "25 | AU-4 | /var/log absent"
fi


# 26 - AC-6 - Permissions configuration Nginx
if [ -d /etc/nginx ]; then

    BAD_NGINX_CONFIG="$(
        find /etc/nginx -xdev \
        \( -type f -o -type d \) \
        -perm /002 2>/dev/null | head -n 1
    )"

    if [ -z "$BAD_NGINX_CONFIG" ]; then
        pass "26 | AC-6 | Aucun fichier Nginx world-writable"
    else
        fail "26 | AC-6 | Permission dangereuse : $BAD_NGINX_CONFIG"
    fi

else
    fail "26 | AC-6 | /etc/nginx absent"
fi


# 27 - AC-6 - Permissions contenu Web
if [ -d /var/www ]; then

    BAD_WEB="$(
        find /var/www -xdev \
        \( -type f -o -type d \) \
        -perm /002 2>/dev/null | head -n 1
    )"

    if [ -z "$BAD_WEB" ]; then
        pass "27 | AC-6 | Aucun contenu Web world-writable"
    else
        fail "27 | AC-6 | Contenu Web world-writable : $BAD_WEB"
    fi

else
    fail "27 | AC-6 | /var/www absent"
fi


# 28 - SC-12 - Permissions clés privées TLS
KEYS="$(
    find /etc/nginx /etc/ssl/private \
    -type f \
    \( -name "*.key" -o -name "*.pem" \) \
    2>/dev/null
)"

if [ -z "$KEYS" ]; then
    manual "28 | SC-12 | Aucune clé TLS identifiée automatiquement"
else

    BAD_KEY=0

    while IFS= read -r key; do
        PERM="$(stat -c '%a' "$key" 2>/dev/null)"

        # Aucun droit pour "others".
        OTHER="${PERM: -1}"

        if [ "$OTHER" != "0" ]; then
            BAD_KEY=1
            break
        fi
    done <<< "$KEYS"

    if [ "$BAD_KEY" -eq 0 ]; then
        pass "28 | SC-12 | Clés TLS non accessibles aux autres utilisateurs"
    else
        fail "28 | SC-12 | Clé TLS avec permissions trop permissives : $key"
    fi
fi


# 29 - AC-6 - Propriétaires contenu Web
if [ -d /var/www ]; then

    BAD_OWNER="$(
        find /var/www -xdev \
        ! -user root \
        ! -user www-data \
        -print 2>/dev/null | head -n 1
    )"

    if [ -z "$BAD_OWNER" ]; then
        pass "29 | AC-6 | Propriétaires du contenu Web conformes"
    else
        manual "29 | AC-6 | Propriétaire à valider : $BAD_OWNER"
    fi

else
    fail "29 | AC-6 | /var/www absent"
fi


# 30 - CM-6 - Montages persistants
if [ -f /etc/fstab ]; then

    if findmnt --verify --tab-file /etc/fstab >/dev/null 2>&1; then
        pass "30 | CM-6 | /etc/fstab valide"
    else
        fail "30 | CM-6 | Erreur détectée dans /etc/fstab"
    fi

else
    fail "30 | CM-6 | /etc/fstab absent"
fi
