# Architecture du Homelab

> Principes et état de conception.
>
> Ce fichier ne décrit pas les manipulations ([Journal.md](Journal.md)), le matériel ([Materiel.md](Materiel.md)), ni les cours détaillés.
> Stockage : [Stockage.md](Stockage.md). Accès distant : [Cloudflare.md](Cloudflare.md). Sauvegardes : [Sauvegardes.md](Sauvegardes.md). Kubernetes : [Kubernetes.md](Kubernetes.md). IP et nœud : [Proxmox.md](Proxmox.md).
> L'index de toute la documentation est dans [README.md](README.md).

---

# Philosophie

Construire une infrastructure : fiable, sécurisée, documentée, maintenable, évolutive.

Ce homelab n'est pas construit dans le but d'obtenir rapidement un résultat. L'objectif est de comprendre chaque technologie utilisée. Chaque choix doit pouvoir être justifié. Chaque commande exécutée doit pouvoir être expliquée.

L'objectif final est de devenir autonome dans la conception, l'administration et le dépannage d'une infrastructure personnelle.

Construire une infrastructure fiable ne consiste pas à éviter les pannes, mais à faire en sorte qu'elles soient prévisibles, limitées et facilement réparables.

Ordre de travail :

> Comprendre → Manipuler → Vérifier → Documenter → Automatiser

Pour chaque nouvelle technologie :

1. Comprendre le problème qu'elle résout.
2. Comprendre son architecture.
3. Identifier les concepts fondamentaux.
4. Observer son fonctionnement.
5. Passer à la pratique.
6. Documenter ce qui a été appris.

Les commandes viennent en dernier. L'objectif est de comprendre les mécanismes plutôt que de mémoriser des procédures.

---

# Principes

## Diagnostic avant action

Un problème ne doit jamais être corrigé au hasard.

1. Observer
2. Émettre une hypothèse
3. Vérifier
4. Identifier la cause racine
5. Corriger
6. Vérifier que le problème est résolu

## Vérifier plutôt que supposer

Toute information doit être vérifiée avant d'être considérée comme vraie : adresses IP, ports, chemins, certificats, DNS, journaux, noms de domaine.

Les hypothèses se confirment par un test (`curl`, `ping`, `systemctl status`, `zpool status`…), pas par une conviction.

Une erreur de configuration est souvent plus probable qu'une défaillance logicielle.

Exemples déjà rencontrés : [Journal.md](Journal.md) (sprints 7 et 8).

## Comprendre avant d'exécuter

Aucune commande n'est exécutée sans comprendre :

- son objectif ;
- son fonctionnement ;
- ce qu'elle modifie ;
- la manière de revenir en arrière.

## Installer ≠ Configurer

Installer un logiciel, c'est le rendre disponible. Le configurer, c'est lui donner son rôle.

Exemple :

```
apt install cloudflared
        ↓
cloudflared service install <token>
```

## Une identité n'est pas un nom

| Identifiant stable | Nom humain (peut changer) |
|--------------------|---------------------------|
| CT ID (`100`) | hostname (`cloudflare`) |
| Tunnel UUID | nom du tunnel |

Les outils d'administration utilisent principalement les identifiants numériques.

## Architecture en couches

Chaque couche dépend de la précédente. Une erreur peut provenir d'une couche inférieure.

```
Applications
    ↑
Services
    ↑
VM / Conteneurs
    ↑
Proxmox
    ↑
Debian
    ↑
Linux
    ↑
Firmware
    ↑
Matériel
```

## Séparation des responsabilités

Chaque service possède son propre environnement d'exécution (un LXC).

Pourquoi : maintenance plus simple, impact d'une panne limité, mises à jour isolées, possibilité de supprimer ou recréer un service sans affecter les autres.

Exemples de rôles : Cloudflare Tunnel, reverse proxy, Home Assistant, Immich, Paperless.

## Moindre privilège

Chaque service ne possède que les droits dont il a réellement besoin.

- LXC non privilégiés ;
- aucun service applicatif installé directement sur Proxmox ;
- chaque application n'a que les accès nécessaires.

Objectif : réduire la surface d'attaque.

## Isolation

Isolation des processus, de la mémoire, du processeur, du stockage et de la configuration.

Une panne ou une faille dans un service ne doit pas impacter le reste de l'infrastructure.

## Ne jamais dépendre d'un seul composant

Ce principe s'applique à plusieurs niveaux :

- redondance disque sur les données (`tank`, miroir IronWolf) — le système (`rpool`) reste sur un seul NVMe ;
- plusieurs couches de sécurité (détail dans [Cloudflare.md](Cloudflare.md)) ;
- isolation des services dans des conteneurs distincts ;
- sauvegardes indépendantes du stockage principal ([Sauvegardes.md](Sauvegardes.md)).

## Ne créer une ressource que lorsqu'un besoin réel apparaît

Dataset, machine virtuelle, conteneur, réseau, utilisateur : rien n'est créé « au cas où ».

L'architecture émerge des besoins plutôt que d'être anticipée sans justification. Cela limite la complexité et facilite l'évolution.

Détail pour ZFS (dataset vs répertoire) : [Stockage.md](Stockage.md).

## Dépôts officiels

Les logiciels sont installés depuis leur dépôt officiel lorsqu'il existe (Debian, Proxmox, Cloudflare).

Objectifs : mises à jour de sécurité, pas de binaires téléchargés à la main, mises à jour via APT.

Tout dépôt APT ajouté doit provenir du projet officiel ou d'une organisation de confiance, et être signé par une clé GPG.

## Secrets

Mots de passe, clés SSH et jetons Cloudflare ne sont jamais partagés ni versionnés dans ce dépôt.

Un Secret Kubernetes n'est **pas chiffré par défaut** (Base64 seulement). Les Secrets d'exercice peuvent être versionnés **temporairement** pour l'apprentissage ; SOPS, Sealed Secrets ou External Secrets viendront ensuite. Détail : [Kubernetes.md](Kubernetes.md).

## Ne jamais ouvrir un service inutilement

Un service n'est exposé que lorsqu'il est nécessaire.

Par défaut : aucune redirection de port, accès uniquement depuis le réseau local.

## Défense en profondeur

Aucune couche ne protège seule l'infrastructure. Le détail des couches d'accès distant est dans [Cloudflare.md](Cloudflare.md).

## Refus par défaut

Tout accès est refusé tant qu'une règle ne l'autorise pas explicitement. Politique Access : [Cloudflare.md](Cloudflare.md).

---

# Stockage

Le SSD NVMe (`rpool`) est réservé à l'infrastructure : Proxmox, VM, LXC, ISO.

Les deux IronWolf (`tank`, miroir ZFS) sont réservés aux données : services, sauvegardes, documents, médias. Aucun dataset de service n'y est créé tant qu'un besoin réel n'existe pas.

Les deux espaces évoluent indépendamment.

Détail : [Stockage.md](Stockage.md). Décision : [ADR-002](ADR/ADR-002-ZFS.md).

---

# Réseau

Le serveur est connecté en Ethernet à la box. Les serveurs ont une IP statique (joignabilité, reverse proxy, tunnels). Les postes utilisateurs peuvent rester en DHCP.

L'administration se fait depuis le LAN. Aucun port Proxmox n'est exposé sur Internet. Accès distant : [Cloudflare.md](Cloudflare.md) et [ADR-003](ADR/ADR-003-Cloudflare-Tunnel.md).

```
Internet
    │
 Routeur
    │
 eno1
    │
 vmbr0
 ├── Proxmox
 ├── Cloudflare
 ├── Home Assistant
 └── ...
```

`vmbr0` est un switch virtuel : les VM et LXC y sont branchés, le bridge est branché sur la carte physique.

Plan d'adressage (source de vérité) : [Proxmox.md](Proxmox.md).

---

# Services

Les services légers tournent dans des LXC Debian Stable.

Avantages : peu de mémoire, démarrage rapide, noyau partagé avec Proxmox, isolation entre services.

Conventions :

- un service = un LXC ;
- hostname = nom du service ;
- exemples : `cloudflare`, `caddy`, `paperless`, `immich`.

Disques des LXC/VM : datasets sous `rpool/data`. ISO, templates, sauvegardes : `rpool/var-lib-vz`. Voir [Stockage.md](Stockage.md).

```
Internet
    │
Cloudflare
    │
Tunnel Cloudflare
    │
LXC Cloudflare
    │
Reverse Proxy (à venir)
    │
Applications
```

---

# Plateforme

Kubernetes est la plateforme visée pour les applications (Vaultwarden, Paperless, Immich…). **Pas encore déployé.**

Les services d'infrastructure légers restent en LXC (Cloudflare aujourd'hui).

Étude : [Kubernetes.md](Kubernetes.md).

---

# Décisions

- [ADR-001](ADR/ADR-001-Proxmox.md) — Proxmox VE
- [ADR-002](ADR/ADR-002-ZFS.md) — ZFS
- [ADR-003](ADR/ADR-003-Cloudflare-Tunnel.md) — Cloudflare Tunnel

---

# Feuille de route

## Fondations

- ✅ Matériel
- ✅ Proxmox
- ✅ Réseau
- ✅ Cloudflare Tunnel
- ✅ Cloudflare Access
- ✅ MFA
- ✅ ZFS (`rpool`)
- ✅ ZFS (`tank`, miroir 2×8 To)
- ⬜ Sauvegardes Proxmox (stratégie écrite, pas encore exécutée)

## Infrastructure

- ⬜ Mise en œuvre des sauvegardes
- ⬜ Tests de restauration
- ⬜ Onduleur
- ⬜ Supervision

## Plateforme

- ⬜ Kubernetes (théorie documentée, cluster non installé)
- ⬜ Caddy

## Services

- ⬜ Vaultwarden
- ⬜ Home Assistant
- ⬜ Paperless
- ⬜ Immich
- ⬜ Site personnel
