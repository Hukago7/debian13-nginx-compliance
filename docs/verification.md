# 2.1 — Méthodes de vérification

L'objectif est d'identifier les outils permettant de vérifier automatiquement les
50 points de contrôle de la baseline Debian 13 / Nginx et d'identifier les
contrôles nécessitant une validation humaine.

## Outils retenus

- Lynis : audit de sécurité et de durcissement du système Debian.
- Trivy : détection de vulnérabilités et problèmes de configuration.
- testssl.sh : analyse de la configuration TLS du serveur Nginx.
- Scripts maison : contrôles réalisés avec les commandes natives Linux.
- Contrôle manuel : validation nécessitant une décision humaine.

## Répartition des contrôles

| ID | Référence | Méthode | Outil principal |
|---:|---|---|---|
| 01 | CM-8 | Automatique | Script maison |
| 02 | SI-2 | Automatique | Script maison / Lynis |
| 03 | CM-8 | Automatique | Script maison |
| 04 | CM-8 | Automatique | Script maison |
| 05 | CM-6 | Semi-automatique | Lynis / Script maison |
| 06 | SI-7 | Automatique | Script maison |
| 07 | CM-7 | Semi-automatique | Lynis / Script maison |
| 08 | AC-6 | Automatique | Lynis / Script maison |
| 09 | AC-6 | Semi-automatique | Lynis / Script maison |
| 10 | IA-5 | Semi-automatique | Lynis / Contrôle manuel |
| 11 | CM-8 | Semi-automatique | Script maison |
| 12 | CM-8 | Semi-automatique | Script maison |
| 13 | CM-6 | Automatique | Script maison |
| 14 | AC-4 | Semi-automatique | Script maison |
| 15 | SC-20 | Automatique | Script maison |
| 16 | CM-7 | Semi-automatique | Lynis / Script maison |
| 17 | SC-8 | Automatique | Script maison |
| 18 | SC-8 | Semi-automatique | Script maison |
| 19 | AC-4 | Semi-automatique | Lynis / Script maison |
| 20 | CM-6 | Semi-automatique | Script maison |
| 21 | CM-6 | Semi-automatique | Lynis / Script maison |
| 22 | CM-7 | Semi-automatique | Lynis / Script maison |
| 23 | CM-6 | Semi-automatique | Lynis / Script maison |
| 24 | AU-4 | Automatique | Script maison |
| 25 | AU-4 | Automatique | Script maison |
| 26 | AC-6 | Automatique | Lynis / Script maison |
| 27 | AC-6 | Automatique | Script maison |
| 28 | SC-12 | Automatique | Script maison |
| 29 | AC-6 | Semi-automatique | Script maison |
| 30 | CM-6 | Automatique | Script maison |
| 31 | CM-7 | Automatique | Script maison |
| 32 | CM-6 | Automatique | Script maison |
| 33 | CM-6 | Automatique | Script maison |
| 34 | SI-2 | Semi-automatique | Script maison / Trivy |
| 35 | AC-6 | Semi-automatique | Script maison |
| 36 | CIS 4.1.2 | Semi-automatique | OpenSSL / testssl.sh |
| 37 | SC-12 | Automatique | OpenSSL / testssl.sh |
| 38 | CIS 4.1.4 | Automatique | testssl.sh |
| 39 | CIS 4.1.5 | Automatique | testssl.sh |
| 40 | CM-7 | Non automatisé | Lynis + contrôle manuel |
| 41 | CM-10 | Semi-automatique | Script maison |
| 42 | SI-2 | Automatique | Script maison / Trivy |
| 43 | SI-2 | Automatique | Script maison / Trivy |
| 44 | CM-7 | Non automatisé | Script maison + contrôle manuel |
| 45 | SI-2 | Automatique | Trivy / Script maison |
| 46 | CM-10 | Non automatisé | Script maison + contrôle manuel |
| 47 | CM-6 | Semi-automatique | Script maison |
| 48 | CM-7 | Non automatisé | Lynis + contrôle manuel |
| 49 | SI-2 | Automatique | Script maison |
| 50 | SA-22 | Non automatisé | Trivy + contrôle manuel |

## Contrôles nécessitant une intervention humaine

Certains contrôles peuvent être inventoriés automatiquement mais leur conformité
ne peut pas être déterminée sans connaître le contexte du serveur.

C'est notamment le cas de :

- 07 : nécessité des modules kernel chargés ;
- 09 : légitimité des comptes de service ;
- 10 : adéquation de la politique d'authentification ;
- 11/12/14 : légitimité de la configuration réseau ;
- 16 : légitimité des ports ouverts ;
- 19 : adéquation des règles de filtrage ;
- 20 : interfaces sur lesquelles Nginx doit réellement écouter ;
- 21/22/23 : adéquation du stockage et des options de montage ;
- 29 : propriétaires attendus du contenu Web ;
- 34 : support de la version Nginx ;
- 35 : compte attendu pour les workers ;
- 40 : nécessité des services actifs ;
- 41 : provenance autorisée de Nginx ;
- 44 : nécessité des modules Nginx ;
- 46 : légitimité des dépôts ;
- 47 : justification des paquets bloqués ;
- 48 : nécessité des paquets installés ;
- 50 : support des composants utilisés.

L'automatisation réalise donc l'inventaire et les vérifications déterministes.
Les contrôles dépendant du besoin métier ou de l'architecture sont soumis à une
validation humaine.