# Baseline de sécurité

## 1. Définition

La baseline décrit **l'état de sécurité attendu du serveur**.

Elle permet de séparer la politique de sécurité de son implémentation.

```text
                    BASELINE
             "État attendu"
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
        AUDIT              REMÉDIATION
 "Est-ce respecté ?"     "Faire respecter"
```

Le fichier utilisé par le projet est :

```text
config/baseline.conf
```

La baseline ne réalise donc pas directement de vérification.

Elle fournit les valeurs auxquelles les scripts d'audit comparent l'état réel de la machine.

---

# 2. Principe

Une conformité n'est pas définie uniquement par la présence ou l'absence d'une vulnérabilité.

Elle correspond ici à une comparaison :

```text
Valeur attendue
      │
      │ baseline.conf
      ▼
   CONTRÔLE
      ▲
      │ collecte système
      │
Valeur observée
```

Si :

```text
observé = attendu
```

le contrôle retourne :

```text
PASS
```

Sinon :

```text
FAIL
```

---

# 3. Exemple : ports réseau

La baseline peut définir :

```bash
ALLOWED_TCP_PORTS="22 80 443"
```

Cela signifie que seuls les ports suivants sont attendus :

| Port | Usage |
|---:|---|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |

## État conforme

Le serveur expose :

```text
22 80 443
```

La comparaison donne :

```text
Baseline : 22 80 443
Système  : 22 80 443
```

Résultat :

```text
PASS
```

## État non conforme

Le serveur expose :

```text
22 80 443 8080
```

Le port `8080` n'appartient pas à la baseline.

Résultat :

```text
FAIL
```

Cela ne signifie pas nécessairement que le port `8080` est vulnérable.

Cela signifie que son exposition **n'est pas autorisée par la politique définie pour ce serveur**.

---

# 4. Une baseline dépend du contexte

Il n'existe pas une unique baseline valable pour tous les systèmes.

Par exemple, considérons trois serveurs.

```text
                Debian
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
   Web Nginx     Bastion       BDD
       │           │           │
    80/443        SSH        PostgreSQL
       │           │           │
    HTTPS        Port 22       Port 5432
```

Le comportement attendu est différent pour chacun.

La baseline doit donc être définie en fonction :

- du rôle du serveur ;
- de son exposition ;
- des services nécessaires ;
- des contraintes d'exploitation ;
- des exigences de sécurité retenues.

---

# 5. Variantes

## Variante Web standard

```bash
ALLOWED_TCP_PORTS="22 80 443"
REQUIRE_HTTP_REDIRECT="yes"
```

SSH permet l'administration, HTTP effectue une redirection et HTTPS fournit le service.

## Variante Web sans SSH exposé

```bash
ALLOWED_TCP_PORTS="80 443"
```

Avec cette baseline :

```text
Port 22 présent → FAIL
```

alors qu'il était autorisé dans la variante précédente.

## Variante HTTPS uniquement

Une politique plus restrictive pourrait être :

```bash
ALLOWED_TCP_PORTS="443"
REQUIRE_HTTP_REDIRECT="no"
```

Le moteur d'audit peut rester identique.

C'est **la baseline qui exprime le changement de politique**.

---

# 6. Exemple TLS

La baseline actuelle définit notamment :

```bash
TLS_ALLOWED_PROTOCOLS="TLSv1.2 TLSv1.3"
CERT_MIN_DAYS=30
FORBIDDEN_CIPHERS="RC4 3DES DES NULL EXPORT MD5"
```

Cela représente la politique :

| Élément | État attendu |
|---|---|
| TLS 1.0 | Interdit |
| TLS 1.1 | Interdit |
| TLS 1.2 | Autorisé |
| TLS 1.3 | Autorisé |
| Certificat | ≥ 30 jours restants |
| Chiffrements faibles définis | Exclus |

Une variante plus restrictive pourrait définir :

```bash
TLS_ALLOWED_PROTOCOLS="TLSv1.3"
```

Dans ce cas, TLS 1.2 deviendrait un écart de conformité pour ce profil.

---

# 7. Exemple filesystem

La baseline peut imposer :

```bash
TMP_REQUIRED_OPTIONS="nodev nosuid noexec"
DEVSHM_REQUIRED_OPTIONS="nodev nosuid noexec"
```

État conforme :

```text
/tmp → nodev,nosuid,noexec
```

État non conforme :

```text
/tmp → nodev,nosuid
```

`noexec` étant absent, le contrôle correspondant retourne `FAIL`.

---

# 8. Exemple packages

Deux types de listes sont utilisés.

```bash
REQUIRED_PACKAGES="nginx openssl unattended-upgrades nftables"

FORBIDDEN_PACKAGES="telnet rsh-client rsh-server talk ftp"
```

La logique est inverse :

```text
REQUIRED_PACKAGES
       │
       ▼
Doivent être installés
       │
  absent = FAIL


FORBIDDEN_PACKAGES
       │
       ▼
Doivent être absents
       │
  présent = FAIL
```

Cela permet d'exprimer simplement plusieurs politiques à partir du même fichier.

---

# 9. Exemple services

La baseline contient également des services explicitement interdits :

```bash
FORBIDDEN_SERVICES="telnet rsh rlogin vsftpd proftpd apache2"
```

Il faut distinguer :

```text
Paquet installé
      ≠
Service actif
```

Les contrôles de paquets et de services répondent donc à des objectifs différents.

---

# 10. Valeurs simples, listes et conditions

La baseline utilise plusieurs types de paramètres.

### Valeur unique

```bash
EXPECTED_OS="debian"
EXPECTED_VERSION="13"
NGINX_USER="www-data"
```

Comparaison :

```text
observé == attendu
```

### Liste autorisée

```bash
ALLOWED_TCP_PORTS="22 80 443"
```

Chaque élément observé doit appartenir à la liste.

### Liste interdite

```bash
FORBIDDEN_PACKAGES="telnet rsh-client rsh-server talk ftp"
```

Aucun élément de la liste ne doit être présent.

### Seuil

```bash
CERT_MIN_DAYS=30
MAX_DISK_USAGE=90
```

Exemples :

```text
certificat >= 30 jours → PASS
disque < 90 %          → PASS
```

### Booléen de politique

```bash
REQUIRE_HTTP_REDIRECT="yes"
REQUIRE_FIREWALL="yes"
REQUIRE_AUTO_UPDATES="yes"
```

Il permet d'activer ou de désactiver une exigence selon le profil retenu.

---

# 11. Évolution vers plusieurs profils

L'architecture permettrait à terme de séparer plusieurs baselines.

```text
config/
├── baseline-web.conf
├── baseline-web-strict.conf
├── baseline-bastion.conf
└── baseline-database.conf
```

Par exemple :

```text
                 Moteur d'audit
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
        WEB         BASTION        BDD
          │            │            │
       80/443          22          5432
```

Les contrôles pourraient ainsi être réutilisés avec plusieurs états de référence.

---

# 12. Baseline et sécurité

Un résultat :

```text
50 / 50 PASS
```

signifie :

> Le serveur respecte l'ensemble des conditions définies dans cette baseline.

Il ne signifie pas :

> Le serveur est exempt de toute vulnérabilité ou de tout risque de sécurité.

C'est notamment pour cette raison que l'audit de conformité est complété par :

```text
Lynis
Trivy
testssl.sh
```

La baseline mesure donc **la conformité à une politique définie**, tandis que les outils complémentaires apportent d'autres angles d'analyse de la sécurité.