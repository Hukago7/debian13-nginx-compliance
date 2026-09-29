mkdir -p config

cat > config/baseline.conf <<'EOF'
# ==========================================================
# BASELINE DE CONFORMITE - DEBIAN 13 / NGINX
# ==========================================================

# --- SYSTEME ---
EXPECTED_OS="debian"
EXPECTED_VERSION="13"
EXPECTED_ARCH="amd64"

# Un seul compte UID 0
ALLOWED_UID0_USERS="root"

# --- RESEAU ---
ALLOWED_TCP_PORTS="22 80 443"

# Le port HTTP est autorisé uniquement pour redirection HTTPS
HTTP_PORT="80"
HTTPS_PORT="443"
REQUIRE_HTTP_REDIRECT="yes"

# Pare-feu obligatoire
REQUIRE_FIREWALL="yes"

# --- NGINX ---
NGINX_USER="www-data"
NGINX_SERVICE="nginx"
REQUIRE_NGINX_ENABLED="yes"

# --- TLS ---
TLS_ALLOWED_PROTOCOLS="TLSv1.2 TLSv1.3"
CERT_MIN_DAYS=30

# Algorithmes explicitement interdits
FORBIDDEN_CIPHERS="RC4 3DES DES NULL EXPORT MD5"

# --- STOCKAGE ---
MAX_DISK_USAGE=90
MAX_INODE_USAGE=90

# Répertoires Web
NGINX_CONFIG_DIR="/etc/nginx"
WEB_ROOT="/var/www"

# --- SERVICES ---
# Liste adaptée à notre serveur Debian/Nginx.
# On l'ajustera après installation de la VM si Debian ajoute
# un service système légitime nécessaire.
ALLOWED_SERVICES="nginx ssh cron systemd-journald systemd-logind dbus"

# --- PAQUETS ---
REQUIRE_AUTO_UPDATES="yes"

# Dépôts autorisés
ALLOWED_REPOSITORIES="deb.debian.org security.debian.org"

# Aucun paquet ne doit être volontairement bloqué
ALLOW_HELD_PACKAGES="no"
EOF