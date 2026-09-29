#!/bin/bash

section "RESEAU / PARE-FEU"

# ==========================================================
# 13 / 15 - Vérifications réseau de base
# ==========================================================

if ip route show default 2>/dev/null | grep -q '^default'; then
    ok "Passerelle par défaut présente"
else
    error "Aucune passerelle par défaut"
fi

if grep -qE '^[[:space:]]*nameserver[[:space:]]+' \
   /etc/resolv.conf 2>/dev/null; then
    ok "Configuration DNS présente"
else
    error "Aucun serveur DNS configuré"
fi


# ==========================================================
# 19 - Pare-feu nftables
# ==========================================================

NFT_FILE="/etc/nftables.conf"

generate_nft_config() {

    cat <<NFT
#!/usr/sbin/nft -f

flush ruleset

table inet filter {

    chain input {
        type filter hook input priority 0;
        policy drop;

        # Connexions déjà établies
        ct state established,related accept

        # Loopback
        iifname "lo" accept

        # ICMP / ICMPv6
        ip protocol icmp accept
        ip6 nexthdr ipv6-icmp accept

NFT

    for port in $ALLOWED_TCP_PORTS; do
        echo "        tcp dport $port accept"
    done

    cat <<'NFT'

        # Tout le reste est refusé par la policy drop
    }

    chain forward {
        type filter hook forward priority 0;
        policy drop;
    }

    chain output {
        type filter hook output priority 0;
        policy accept;
    }
}
NFT
}

EXPECTED_NFT="$(generate_nft_config)"
CURRENT_NFT=""

if [ -f "$NFT_FILE" ]; then
    CURRENT_NFT="$(cat "$NFT_FILE")"
fi

if [ "$CURRENT_NFT" = "$EXPECTED_NFT" ]; then

    ok "Configuration nftables déjà conforme"

else

    printf '%s\n' "$EXPECTED_NFT" > "$NFT_FILE"

    if nft -c -f "$NFT_FILE" >/dev/null 2>&1; then
        changed "Configuration nftables mise à jour"
    else
        error "Configuration nftables générée invalide"
    fi

fi


# ==========================================================
# Application du ruleset
# ==========================================================

if nft -c -f "$NFT_FILE" >/dev/null 2>&1; then

    # On compare le fichier ; le chargement n'est pas compté comme
    # changement supplémentaire.
    if nft -f "$NFT_FILE" >/dev/null 2>&1; then
        ok "Ruleset nftables chargé"
    else
        error "Impossible de charger nftables"
    fi

else
    error "Impossible de valider $NFT_FILE"
fi


# ==========================================================
# Activation au démarrage
# ==========================================================

if systemctl is-enabled --quiet nftables 2>/dev/null; then

    ok "nftables activé au démarrage"

else

    if systemctl enable nftables >/dev/null 2>&1; then
        changed "Activation de nftables au démarrage"
    else
        error "Impossible d'activer nftables"
    fi

fi


# ==========================================================
# Démarrage du service
# ==========================================================

if systemctl is-active --quiet nftables 2>/dev/null; then

    ok "nftables actif"

else

    if systemctl start nftables >/dev/null 2>&1; then
        changed "Démarrage de nftables"
    else
        error "Impossible de démarrer nftables"
    fi

fi
