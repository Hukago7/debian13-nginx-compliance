#!/bin/bash

echo
echo "========== RESEAU =========="
echo

# 11 - CM-8 - Interfaces réseau
INTERFACES="$(ip -o link show 2>/dev/null | awk -F': ' '$2 != "lo" {print $2}' | xargs)"

if [ -n "$INTERFACES" ]; then
    pass "11 | CM-8 | Interfaces réseau détectées : $INTERFACES"
else
    fail "11 | CM-8 | Aucune interface réseau hors loopback détectée"
fi


# 12 - CM-8 - Adressage IP
ADDRESSES="$(
    ip -o -4 addr show scope global 2>/dev/null |
    awk '{print $4}' |
    xargs
)"

if [ -n "$ADDRESSES" ]; then
    pass "12 | CM-8 | Adresses IPv4 configurées : $ADDRESSES"
else
    fail "12 | CM-8 | Aucune adresse IPv4 globale détectée"
fi


# 13 - CM-6 - Passerelle
GATEWAY="$(ip route show default 2>/dev/null | head -n1)"

if [ -n "$GATEWAY" ]; then
    pass "13 | CM-6 | Passerelle par défaut configurée : $GATEWAY"
else
    fail "13 | CM-6 | Aucune passerelle par défaut"
fi


# 14 - AC-4 - Routage IP
# Le serveur Nginx ne doit pas agir comme routeur.
IP_FORWARD="$(sysctl -n net.ipv4.ip_forward 2>/dev/null)"

if [ "$IP_FORWARD" = "0" ]; then
    pass "14 | AC-4 | Routage IPv4 désactivé"
else
    fail "14 | AC-4 | net.ipv4.ip_forward=$IP_FORWARD (attendu : 0)"
fi


# 15 - SC-20 - DNS
DNS_SERVERS="$(
    awk '/^[[:space:]]*nameserver[[:space:]]+/ {print $2}' \
    /etc/resolv.conf 2>/dev/null |
    xargs
)"

if [ -n "$DNS_SERVERS" ]; then
    pass "15 | SC-20 | DNS configuré : $DNS_SERVERS"
else
    fail "15 | SC-20 | Aucun serveur DNS configuré"
fi


# 16 - CM-7 - Ports TCP autorisés
if ! command -v ss >/dev/null 2>&1; then
    fail "16 | CM-7 | Commande ss indisponible"
else
    LISTENING_PORTS="$(
        ss -H -lnt 2>/dev/null |
        awk '{print $4}' |
        sed -E 's/.*:([0-9]+)$/\1/' |
        sort -nu
    )"

    UNAUTHORIZED=""

    for port in $LISTENING_PORTS; do
        case " $ALLOWED_TCP_PORTS " in
            *" $port "*) ;;
            *) UNAUTHORIZED="$UNAUTHORIZED $port" ;;
        esac
    done

    if [ -z "$UNAUTHORIZED" ]; then
        pass "16 | CM-7 | Aucun port TCP non autorisé détecté : $(echo "$LISTENING_PORTS" | xargs)"
    else
        fail "16 | CM-7 | Ports TCP non autorisés :$UNAUTHORIZED"
    fi
fi


# 17 - SC-8 - HTTPS
if ss -H -lnt 2>/dev/null |
   awk '{print $4}' |
   grep -qE ":${HTTPS_PORT}$"; then

    pass "17 | SC-8 | HTTPS écoute sur le port $HTTPS_PORT"
else
    fail "17 | SC-8 | Aucun service en écoute sur HTTPS/$HTTPS_PORT"
fi


# 18 - SC-8 - Redirection HTTP vers HTTPS
if [ "$REQUIRE_HTTP_REDIRECT" = "yes" ]; then

    if ! command -v nginx >/dev/null 2>&1; then
        fail "18 | SC-8 | Nginx absent : redirection HTTP impossible à vérifier"

    elif ! ss -H -lnt 2>/dev/null |
         awk '{print $4}' |
         grep -qE ":${HTTP_PORT}$"; then

        fail "18 | SC-8 | Port HTTP/$HTTP_PORT non actif alors que la redirection est requise"

    elif nginx -T 2>/dev/null |
         grep -Eq 'return[[:space:]]+30(1|8)[[:space:]]+https://'; then

        pass "18 | SC-8 | Redirection HTTP vers HTTPS configurée"

    else
        fail "18 | SC-8 | Redirection HTTP vers HTTPS non détectée"
    fi

else
    pass "18 | SC-8 | Redirection HTTP non exigée par la baseline"
fi


# 19 - AC-4 - Pare-feu
if [ "$REQUIRE_FIREWALL" != "yes" ]; then
    pass "19 | AC-4 | Pare-feu non exigé par la baseline"

elif command -v nft >/dev/null 2>&1; then

    RULESET="$(nft list ruleset 2>/dev/null)"

    if [ -n "$RULESET" ] &&
       echo "$RULESET" | grep -qE 'hook[[:space:]]+input'; then
        pass "19 | AC-4 | Pare-feu nftables actif"
    else
        fail "19 | AC-4 | nftables présent mais aucun filtrage INPUT détecté"
    fi

elif command -v iptables >/dev/null 2>&1; then

    IPTABLES_RULES="$(iptables -S INPUT 2>/dev/null)"

    if [ -n "$IPTABLES_RULES" ]; then
        pass "19 | AC-4 | Filtrage iptables INPUT détecté"
    else
        fail "19 | AC-4 | Aucun filtrage iptables INPUT détecté"
    fi

else
    fail "19 | AC-4 | Aucun pare-feu compatible détecté"
fi


# 20 - CM-6 - Ports Nginx
if ! command -v nginx >/dev/null 2>&1; then
    fail "20 | CM-6 | Nginx absent"
else
    NGINX_LISTEN_PORTS="$(
        nginx -T 2>/dev/null |
        awk '
            /^[[:space:]]*listen[[:space:]]/ {
                value=$2
                gsub(";", "", value)
                if (match(value, /[0-9]+$/)) {
                    print substr(value, RSTART, RLENGTH)
                }
            }
        ' |
        sort -nu
    )"

    BAD_NGINX_PORTS=""

    for port in $NGINX_LISTEN_PORTS; do
        if [ "$port" != "$HTTP_PORT" ] &&
           [ "$port" != "$HTTPS_PORT" ]; then
            BAD_NGINX_PORTS="$BAD_NGINX_PORTS $port"
        fi
    done

    if [ -z "$NGINX_LISTEN_PORTS" ]; then
        fail "20 | CM-6 | Aucune directive listen Nginx détectée"
    elif [ -n "$BAD_NGINX_PORTS" ]; then
        fail "20 | CM-6 | Ports Nginx non autorisés :$BAD_NGINX_PORTS"
    else
        pass "20 | CM-6 | Ports Nginx conformes : $(echo "$NGINX_LISTEN_PORTS" | xargs)"
    fi
fi