#!/bin/bash

section "SERVICES"

# ==========================================================
# Services interdits
# ==========================================================

for service in $FORBIDDEN_SERVICES; do

    # Le service n'existe pas
    if ! systemctl list-unit-files "${service}.service" \
        --no-legend 2>/dev/null |
        grep -q "^${service}.service"; then

        ok "$service non installé"
        continue
    fi

    # Arrêt
    if systemctl is-active --quiet "$service" 2>/dev/null; then

        if systemctl stop "$service" >/dev/null 2>&1; then
            changed "Arrêt du service interdit $service"
        else
            error "Impossible d'arrêter $service"
        fi

    else
        ok "$service inactif"
    fi

    # Désactivation
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then

        if systemctl disable "$service" >/dev/null 2>&1; then
            changed "Désactivation de $service"
        else
            error "Impossible de désactiver $service"
        fi

    else
        ok "$service non activé au démarrage"
    fi

done
