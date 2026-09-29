#!/bin/bash

echo
echo "========== RESEAU =========="
echo

# 11 - CM-8 - Interfaces réseau
INTERFACES="$(ip -o link show 2>/dev/null | awk -F': ' '$2 != "lo" {print $2}' | xargs)"

if [ -n "$INTERFACES" ]; then
    manual "11 | CM-8 | Interfaces détectées : $INTERFACES"
else
    fail "11 | CM-8 | Impossible d'inventorier les interfaces réseau"
fi


# 12 - CM-8 - Adressage IPv4 / IPv6
ADDRESSES="$(ip -br addr show 2>/dev/null | grep -v '^lo' | xargs)"

if [ -n "$ADDRESSES" ]; then
    manual "12 | CM-8 | Adressage détecté : $ADDRESSES"
else
    fail "12 | CM-8 | Aucune adresse réseau détectée"
fi


# 13 - CM-6 - Passerelle par défaut
GATEWAY="$(ip route show default 2>/dev/null | head -n1)"

if [ -n "$GATEWAY" ]; then
    pass "13 | CM-6 | Passerelle configurée : $GATEWAY"
else
    fail "13 | CM-6 | Aucune passerelle par défaut"
fi


# 14 - AC-4 - Routes
ROUTES="$(ip route show 2>/dev/null)"

if [ -n "$ROUTES" ]; then
    manual "14 | AC-4 | Table de routage présente : validation nécessaire"
else
    fail "14 | AC-4 | Impossible de récupérer la table de routage"
fi


# 15 - SC-20 - DNS
if [ -s /etc/resolv.conf ] && grep -qE '^[[:space:]]*nameserver[[:space:]]+' /etc/resolv.conf; then
    pass "15 | SC-20 | Serveur DNS configuré"
else
    fail "15 | SC-20 | Aucun serveur DNS détecté"
fi


# 16 - CM-7 - Ports TCP en écoute
LISTENING="$(ss -lnt 2>/dev/null | tail -n +2)"

if [ -n "$LISTENING" ]; then
    manual "16 | CM-7 | Ports TCP en écoute détectés : validation nécessaire"
else
    fail "16 | CM-7 | Aucun port TCP détecté ou commande indisponible"
fi


# 17 - SC-8 - HTTPS / 443
if ss -lnt 2>/dev/null | awk '{print $4}' | grep -qE '(^|:|\])443$'; then
    pass "17 | SC-8 | HTTPS écoute sur le port 443"
else
    fail "17 | SC-8 | Aucun service HTTPS détecté sur 443"
fi


# 18 - SC-8 - HTTP / 80
# La présence de HTTP nécessite de vérifier qu'il ne sert qu'à rediriger vers HTTPS.
if ss -lnt 2>/dev/null | awk '{print $4}' | grep -qE '(^|:|\])80$'; then
    manual "18 | SC-8 | Port 80 actif : vérifier la redirection HTTP vers HTTPS"
else
    pass "18 | SC-8 | Aucun service HTTP en clair sur le port 80"
fi


# 19 - AC-4 - Pare-feu
if command -v nft >/dev/null 2>&1; then
    RULESET="$(nft list ruleset 2>/dev/null)"

    if [ -n "$RULESET" ]; then
        manual "19 | AC-4 | Pare-feu nftables présent : règles à valider"
    else
        fail "19 | AC-4 | nftables présent mais aucune règle détectée"
    fi
elif command -v iptables >/dev/null 2>&1; then
    manual "19 | AC-4 | iptables détecté : règles à valider"
else
    fail "19 | AC-4 | Aucun pare-feu nftables/iptables détecté"
fi


# 20 - CM-6 - Adresses d'écoute Nginx
if command -v nginx >/dev/null 2>&1; then
    LISTEN="$(nginx -T 2>/dev/null | grep -E '^[[:space:]]*listen[[:space:]]')"

    if [ -n "$LISTEN" ]; then
        manual "20 | CM-6 | Directives listen Nginx détectées : $LISTEN"
    else
        fail "20 | CM-6 | Aucune directive listen Nginx détectée"
    fi
else
    fail "20 | CM-6 | Nginx n'est pas installé"
fi
