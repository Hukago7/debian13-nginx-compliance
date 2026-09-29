#!/bin/bash

echo
echo "========== STOCKAGE / PERMISSIONS =========="
echo

# ==========================================================
# 21 - CM-6 - Partitionnement
# ==========================================================
# Une partition racine doit exister et être montée.

ROOT_SOURCE="$(findmnt -n -o SOURCE / 2>/dev/null)"

if [ -n "$ROOT_SOURCE" ]; then
    pass "21 | CM-6 | Système racine monté depuis : $ROOT_SOURCE"
else
    fail "21 | CM-6 | Impossible d'identifier le stockage de /"
fi


# ==========================================================
# 22 - CM-7 - Filesystems interdits
# ==========================================================

BAD_FS=""

for fs in $FORBIDDEN_FILESYSTEMS; do

    if grep -qw "$fs" /proc/filesystems 2>/dev/null ||
       findmnt -rn -t "$fs" >/dev/null 2>&1; then

        BAD_FS="$BAD_FS $fs"
    fi

done

if [ -z "$BAD_FS" ]; then
    pass "22 | CM-7 | Aucun filesystem interdit détecté"
else
    fail "22 | CM-7 | Filesystems interdits disponibles/utilisés :$BAD_FS"
fi


# ==========================================================
# 23 - CM-6 - Options de montage sécurisées
# ==========================================================

check_mount_options() {

    TARGET="$1"
    REQUIRED="$2"

    if ! findmnt "$TARGET" >/dev/null 2>&1; then
        return 1
    fi

    OPTIONS="$(findmnt -n -o OPTIONS "$TARGET" 2>/dev/null)"

    MISSING=""

    for option in $REQUIRED; do
        if ! echo ",$OPTIONS," | grep -q ",$option,"; then
            MISSING="$MISSING $option"
        fi
    done

    if [ -z "$MISSING" ]; then
        return 0
    else
        return 1
    fi
}

MOUNT_ERROR=""

if ! check_mount_options "/tmp" "$TMP_REQUIRED_OPTIONS"; then
    MOUNT_ERROR="$MOUNT_ERROR /tmp"
fi

if ! check_mount_options "/dev/shm" "$DEVSHM_REQUIRED_OPTIONS"; then
    MOUNT_ERROR="$MOUNT_ERROR /dev/shm"
fi

if [ -z "$MOUNT_ERROR" ]; then
    pass "23 | CM-6 | Options de montage sécurisées conformes"
else
    fail "23 | CM-6 | Options de montage non conformes :$MOUNT_ERROR"
fi


# ==========================================================
# 24 - AU-4 - Utilisation disque
# ==========================================================

ROOT_USAGE="$(
    df -P / 2>/dev/null |
    awk 'NR==2 {gsub("%","",$5); print $5}'
)"

if [[ "$ROOT_USAGE" =~ ^[0-9]+$ ]] &&
   [ "$ROOT_USAGE" -lt "$MAX_DISK_USAGE" ]; then

    pass "24 | AU-4 | Utilisation disque conforme : ${ROOT_USAGE}%"
else
    fail "24 | AU-4 | Utilisation disque : ${ROOT_USAGE}% (limite : ${MAX_DISK_USAGE}%)"
fi


# ==========================================================
# 25 - AU-4 - /var/log
# ==========================================================

LOG_USAGE="$(
    df -P /var/log 2>/dev/null |
    awk 'NR==2 {gsub("%","",$5); print $5}'
)"

LOG_INODES="$(
    df -Pi /var/log 2>/dev/null |
    awk 'NR==2 {gsub("%","",$5); print $5}'
)"

if [[ "$LOG_USAGE" =~ ^[0-9]+$ ]] &&
   [[ "$LOG_INODES" =~ ^[0-9]+$ ]] &&
   [ "$LOG_USAGE" -lt "$MAX_DISK_USAGE" ] &&
   [ "$LOG_INODES" -lt "$MAX_INODE_USAGE" ]; then

    pass "25 | AU-4 | /var/log : disque ${LOG_USAGE}% / inodes ${LOG_INODES}%"
else
    fail "25 | AU-4 | /var/log non conforme : disque=${LOG_USAGE}% inodes=${LOG_INODES}%"
fi


# ==========================================================
# 26 - AC-6 - Permissions /etc/nginx
# ==========================================================

if [ ! -d "$NGINX_CONFIG_DIR" ]; then
    fail "26 | AC-6 | $NGINX_CONFIG_DIR absent"
else

    BAD_NGINX_PERMS="$(
        find "$NGINX_CONFIG_DIR" -xdev \
        \( -type f -o -type d \) \
        -perm /022 \
        -print 2>/dev/null |
        head -n1
    )"

    BAD_NGINX_OWNER="$(
        find "$NGINX_CONFIG_DIR" -xdev \
        ! -user root \
        -print 2>/dev/null |
        head -n1
    )"

    if [ -z "$BAD_NGINX_PERMS" ] &&
       [ -z "$BAD_NGINX_OWNER" ]; then

        pass "26 | AC-6 | Configuration Nginx protégée et détenue par root"
    else
        fail "26 | AC-6 | Permissions/propriétaire incorrects dans $NGINX_CONFIG_DIR"
    fi
fi


# ==========================================================
# 27 - AC-6 - Permissions contenu Web
# ==========================================================

if [ ! -d "$WEB_ROOT" ]; then
    fail "27 | AC-6 | $WEB_ROOT absent"
else

    BAD_WEB="$(
        find "$WEB_ROOT" -xdev \
        \( -type f -o -type d \) \
        -perm /002 \
        -print 2>/dev/null |
        head -n1
    )"

    if [ -z "$BAD_WEB" ]; then
        pass "27 | AC-6 | Aucun contenu Web world-writable"
    else
        fail "27 | AC-6 | Contenu Web world-writable : $BAD_WEB"
    fi
fi


# ==========================================================
# 28 - SC-12 - Permissions clés privées TLS
# ==========================================================

KEYS=""

if command -v nginx >/dev/null 2>&1; then
    KEYS="$(
        nginx -T 2>/dev/null |
        awk '
            $1 == "ssl_certificate_key" {
                gsub(";", "", $2)
                print $2
            }
        ' |
        sort -u
    )"
fi

if [ -z "$KEYS" ]; then

    fail "28 | SC-12 | Aucune clé privée TLS Nginx détectée"

else

    BAD_KEYS=""

    while IFS= read -r key; do

        [ -z "$key" ] && continue

        if [ ! -f "$key" ]; then
            BAD_KEYS="$BAD_KEYS $key(absente)"
            continue
        fi

        MODE="$(stat -c '%a' "$key" 2>/dev/null)"
        OWNER="$(stat -c '%U' "$key" 2>/dev/null)"

        # On refuse tout accès pour "others".
        OTHER="${MODE: -1}"

        if [ "$OWNER" != "root" ] ||
           [ "$OTHER" != "0" ]; then
            BAD_KEYS="$BAD_KEYS $key"
        fi

    done <<< "$KEYS"

    if [ -z "$BAD_KEYS" ]; then
        pass "28 | SC-12 | Permissions des clés privées TLS conformes"
    else
        fail "28 | SC-12 | Clés privées TLS non conformes :$BAD_KEYS"
    fi
fi


# ==========================================================
# 29 - AC-6 - Propriétaires contenu Web
# ==========================================================

if [ ! -d "$WEB_ROOT" ]; then

    fail "29 | AC-6 | $WEB_ROOT absent"

else

    BAD_OWNER=""

    while IFS= read -r owner; do

        [ -z "$owner" ] && continue

        case " $WEB_ALLOWED_OWNERS " in
            *" $owner "*) ;;
            *) BAD_OWNER="$BAD_OWNER $owner" ;;
        esac

    done < <(
        find "$WEB_ROOT" -xdev \
        -printf '%u\n' 2>/dev/null |
        sort -u
    )

    if [ -z "$BAD_OWNER" ]; then
        pass "29 | AC-6 | Propriétaires du contenu Web conformes"
    else
        fail "29 | AC-6 | Propriétaires Web non autorisés :$BAD_OWNER"
    fi
fi


# ==========================================================
# 30 - CM-6 - /etc/fstab
# ==========================================================

if [ ! -f /etc/fstab ]; then

    fail "30 | CM-6 | /etc/fstab absent"

elif ! command -v findmnt >/dev/null 2>&1; then

    fail "30 | CM-6 | findmnt indisponible"

elif findmnt --verify --tab-file /etc/fstab >/dev/null 2>&1; then

    pass "30 | CM-6 | Configuration /etc/fstab valide"

else
    fail "30 | CM-6 | Erreur détectée dans /etc/fstab"
fi