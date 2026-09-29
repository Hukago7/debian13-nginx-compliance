# Debian 13 / Nginx Compliance

Projet d'audit et de mise en conformité d'un serveur Debian 13 hébergeant Nginx HTTPS.

## Objectifs

- Vérifier une baseline de 50 points de contrôle.
- Automatiser les contrôles lorsque cela est possible.
- Identifier les contrôles nécessitant une validation humaine.
- Corriger automatiquement les écarts.
- Atteindre 100 % de conformité.
- Garantir l'idempotence de la remédiation.

## Outils

- Lynis
- Trivy
- testssl.sh
- Scripts Bash
- Ansible

## Utilisation

Audit :

```bash
sudo ./audit/audit.sh