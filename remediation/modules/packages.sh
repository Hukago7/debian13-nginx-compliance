#!/bin/bash

section "PAQUETS"

if ! command -v apt-get >/dev/null 2>&1; then
    error "apt-get indisponible : ce système n'est pas compatible avec cette remédiation"
else

    # ------------------------------------------------------
    # Mise à jour de l'index APT
    # ------------------------------------------------------

    if apt-get update >/dev/null 2>&1; then
        ok "Index APT mis à jour"
    else
        error "Échec de apt-get update"
    fi


    # ------------------------------------------------------
    # Installation des paquets obligatoires
    # ------------------------------------------------------

    for package in $REQUIRED_PACKAGES; do

        if dpkg-query -W -f='${db:Status-Status}' \
           "$package" 2>/dev/null | grep -qx "installed"; then

            ok "$package déjà installé"

        else

            if DEBIAN_FRONTEND=noninteractive \
               apt-get install -y "$package" >/dev/null 2>&1; then

                changed "Installation de $package"
            else
                error "Impossible d'installer $package"
            fi
        fi

    done


    # ------------------------------------------------------
    # Suppression des paquets interdits
    # ------------------------------------------------------

    for package in $FORBIDDEN_PACKAGES; do

        if dpkg-query -W -f='${db:Status-Status}' \
           "$package" 2>/dev/null | grep -qx "installed"; then

            if DEBIAN_FRONTEND=noninteractive \
               apt-get purge -y "$package" >/dev/null 2>&1; then

                changed "Suppression du paquet interdit $package"
            else
                error "Impossible de supprimer $package"
            fi

        else
            ok "$package absent"
        fi

    done


    # ------------------------------------------------------
    # Paquets en hold
    # ------------------------------------------------------

    if [ "$ALLOW_HELD_PACKAGES" = "no" ]; then

        HELD="$(apt-mark showhold 2>/dev/null)"

        if [ -z "$HELD" ]; then
            ok "Aucun paquet bloqué"
        else

            while IFS= read -r package; do
                [ -z "$package" ] && continue

                if apt-mark unhold "$package" >/dev/null 2>&1; then
                    changed "Suppression du hold sur $package"
                else
                    error "Impossible de débloquer $package"
                fi
            done <<< "$HELD"

        fi
    fi


    # ------------------------------------------------------
    # Mise à jour des paquets installés
    # ------------------------------------------------------

    UPGRADABLE="$(
        apt list --upgradable 2>/dev/null |
        tail -n +2
    )"

    if [ -z "$UPGRADABLE" ]; then

        ok "Système déjà à jour"

    else

        if DEBIAN_FRONTEND=noninteractive \
           apt-get upgrade -y >/dev/null 2>&1; then

            changed "Mise à jour des paquets"
        else
            error "Échec de la mise à jour des paquets"
        fi

    fi


    # ------------------------------------------------------
    # unattended-upgrades
    # ------------------------------------------------------

    AUTO_FILE="/etc/apt/apt.conf.d/20auto-upgrades"

    EXPECTED_AUTO='APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";'

    if [ "$REQUIRE_AUTO_UPDATES" = "yes" ]; then

        CURRENT_AUTO=""

        if [ -f "$AUTO_FILE" ]; then
            CURRENT_AUTO="$(cat "$AUTO_FILE")"
        fi

        if [ "$CURRENT_AUTO" = "$EXPECTED_AUTO" ]; then

            ok "Mises à jour automatiques déjà configurées"

        else

            printf '%s\n' "$EXPECTED_AUTO" > "$AUTO_FILE"

            changed "Configuration de unattended-upgrades"
        fi
    fi

fi
