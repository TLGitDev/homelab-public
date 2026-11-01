# Architecture du Homelab

> Principes et état de conception.
>
> Ce fichier ne décrit pas les manipulations ([Journal.md](Journal.md)), le matériel ([Materiel.md](Materiel.md)), ni les cours détaillés.
> Stockage : [Stockage.md](Stockage.md). Accès distant : [Cloudflare.md](Cloudflare.md). Sauvegardes : [Sauvegardes.md](Sauvegardes.md). Kubernetes : [Kubernetes.md](Kubernetes.md). GitOps : [ArgoCD.md](ArgoCD.md). Vaultwarden : [Vaultwarden.md](Vaultwarden.md). IP et nœud : [Proxmox.md](Proxmox.md). Cible : [FeuilleDeRoute.md](FeuilleDeRoute.md).
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

Les services d'infrastructure légers ont chacun leur LXC. Les applications tournent sur K3s (ressources Kubernetes distinctes).

Pourquoi : maintenance plus simple, impact d'une panne limité, mises à jour isolées, possibilité de supprimer ou recréer un service sans affecter les autres.

Exemples : LXC Cloudflare Tunnel ; Vaultwarden sur le cluster. D'autres applis : [FeuilleDeRoute.md](FeuilleDeRoute.md).

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

Un Secret Kubernetes n'est **pas chiffré par défaut** (Base64 seulement). Dans Git, les secrets applicatifs sont des **SealedSecrets**. Détail : [Vaultwarden.md](Vaultwarden.md#sealed-secrets).

## Ne jamais ouvrir un service inutilement

Un service n'est exposé que lorsqu'il est nécessaire.

Par défaut : aucune redirection de port, accès uniquement depuis le réseau local.

## Défense en profondeur

Aucune couche ne protège seule l'infrastructure. Le détail des couches d'accès distant est dans [Cloudflare.md](Cloudflare.md).

## Refus par défaut

Pour les services derrière Access (Proxmox, Argo CD), tout accès est refusé tant qu'une règle ne l'autorise pas. Vaultwarden n'est pas derrière Access. Visé le 1er nov., pas joué : les interfaces *arr derrière Access, Navidrome sans Access. Politique : [Cloudflare.md](Cloudflare.md).

---

# Stockage

Le SSD NVMe (`rpool`) est l'**infrastructure** : Proxmox, disques système des VM/CT (dont `k3s-01`).

`tank` (miroir IronWolf) est destiné aux **données** qui doivent survivre à une reconstruction de `rpool`.

**Aujourd'hui** : Vaultwarden est sur `tank/vmdata/vm-101-vaultwarden-data` (zvol → ext4 → Local PV → `vaultwarden-zfs-pvc`). L'ancien PVC `local-path` est conservé figé. Pas de NFS pour SQLite, pas de CSI ZFS. [ADR-008](ADR/ADR-008-Vaultwarden-tank.md).

Sauvegardes quotidiennes en place (tar 03:00 → `pve` 03:15). Restore isolée OK (technique 20 oct. ; login + coffre 21 oct.). Reprise réelle (zvol) : procédure écrite, non exécutée. USB Restic manuel.

Détail : [Stockage.md](Stockage.md). As-built : [Vaultwarden.md](Vaultwarden.md).

---

# Réseau

Le serveur est connecté en Ethernet à la box. Les serveurs ont une IP statique (joignabilité, reverse proxy, tunnels). Les postes utilisateurs peuvent rester en DHCP.

L'administration se fait depuis le LAN. Aucun port Proxmox n'est exposé sur Internet. L'**API Kubernetes n'est pas publiée** sur Internet. Accès distant : [Cloudflare.md](Cloudflare.md) et [ADR-003](ADR/ADR-003-Cloudflare-Tunnel.md).

```
Internet
    │
 Routeur
    │
 eno1
    │
 vmbr0
 ├── Proxmox (.50)
 ├── Cloudflare (.20)
 ├── K3s (.30)
 └── ...
```

`vmbr0` est un switch virtuel : les VM et LXC y sont branchés, le bridge est branché sur la carte physique.

Plan d'adressage (source de vérité) : [Proxmox.md](Proxmox.md).

---

# Services

Les services d'infrastructure légers tournent dans des LXC Debian Stable.

Avantages : peu de mémoire, démarrage rapide, noyau partagé avec Proxmox, isolation entre services.

Conventions LXC :

- un service d'infra = un LXC ;
- hostname = nom du service ;
- exemple : `cloudflare`.

Les applications actuelles (Vaultwarden) sont des ressources Kubernetes sur K3s, pas des LXC. Les suivants se choisissent selon le besoin (K3s, LXC, VM). [FeuilleDeRoute.md](FeuilleDeRoute.md).

Disques **système** des LXC/VM : datasets sous `rpool/data` (k3s-01 : `vm-101-disk-1`, 64 Go). Volumes de **données** : `tank/vmdata` (`tank-vmdata`) — Vaultwarden : `vm-101-vaultwarden-data`. [ADR-008](ADR/ADR-008-Vaultwarden-tank.md). ISO, templates : `rpool/var-lib-vz`. Voir [Stockage.md](Stockage.md).

```
Internet
    │
Cloudflare
    │
Tunnel Cloudflare
    │
LXC Cloudflare
    │
Traefik (K3s, <ip-k3s-01>:80)
    │
Applications (Ingress → Service → Pod)
```

Premier service : [Vaultwarden.md](Vaultwarden.md). UI GitOps : [ArgoCD.md](ArgoCD.md) (`argocd.labo.example`, Access). Proxmox reste une route directe du tunnel (HTTPS vers le nœud), pas via Traefik.

---

# Plateforme

Kubernetes (K3s, `<ip-k3s-01>`) est la plateforme des applications. Traefik est l'Ingress Controller. GitOps : [ArgoCD.md](ArgoCD.md). Premier service : [Vaultwarden.md](Vaultwarden.md).

Les services d'infrastructure légers restent en LXC (Cloudflare aujourd'hui).

Cours : [Kubernetes.md](Kubernetes.md).

---

# Décisions

- [ADR-001](ADR/ADR-001-Proxmox.md) — Proxmox VE
- [ADR-002](ADR/ADR-002-ZFS.md) — ZFS
- [ADR-003](ADR/ADR-003-Cloudflare-Tunnel.md) — Cloudflare Tunnel
- [ADR-004](ADR/ADR-004-K3s.md) — K3s (mono-nœud)
- [ADR-005](ADR/ADR-005-Sealed-Secrets.md) — Sealed Secrets
- [ADR-006](ADR/ADR-006-Argo-CD.md) — Argo CD
- [ADR-007](ADR/ADR-007-Argo-CD-exposition.md) — Exposition Argo CD
- [ADR-008](ADR/ADR-008-Vaultwarden-tank.md) — Vaultwarden : zvol sur `tank` + Local PV

---

# État (as-built)

Cible et phases : [FeuilleDeRoute.md](FeuilleDeRoute.md). Ici : ce qui est **en place**.

Scripts d'exploitation : [`infrastructure/`](../infrastructure/) (k3s-01, pve). Git ≠ `/usr/local/sbin`. Chaîne : [Sauvegardes.md](Sauvegardes.md#chaîne-actuelle).

## Fondations

- ✅ Matériel
- ✅ Proxmox
- ✅ Réseau
- ✅ Cloudflare Tunnel
- ✅ Cloudflare Access
- ✅ MFA
- ✅ ZFS (`rpool`)
- ✅ ZFS (`tank`, miroir 2×8 To)
- ✅ Onduleur (protège le serveur)
- ⚙️ Sauvegardes : tars + restore isolée OK ; snapshots zvol horaires OK — [Sauvegardes.md](Sauvegardes.md#chaîne-actuelle)

## Infrastructure

- ✅ Snapshots zvol Vaultwarden (horaires auto ; daily timer 22 oct.)
- ✅ USB / Restic : `backup-usb` (20 oct.) ; clé Sealed Secrets sous `/tank/backups/k3s-01/sealed-secrets/`
- ⬜ Supervision
- ✅ Phase 1 : perso sur `tank` ; `backup-usb` élargi OK ; SMB LXC `samba` (CT 102, `.40`) — (document privé)
- ✅ Phase 2 : close le 25 oct. Snapshot `<snapshot>`. Restore du `.vcf` OK. Photos et SMS gardés en sauvegarde, sans restore. — (document privé)

## Plateforme

- ✅ K3s (`<ip-k3s-01>`) + Traefik
- ✅ Argo CD (GitOps, Vaultwarden)

## Services

- ✅ Vaultwarden (`https://vaultwarden.labo.example`) — données sur `tank` (`vaultwarden-zfs-pvc`)
- ✅ Jellyfin : LXC 103, `<ip-jellyfin>:8096`, lecture seule sur `tank/mediatheques`. Scan terminé, un film lu (28 oct.). [Mediatheques.md](Mediatheques.md)
- ✅ qBittorrent : LXC 104, `<ip-qbittorrent>:8080`, écriture sur `telechargements/` seulement. Proton VPN pour ce compte (29 oct.). Mullvad gardé. Image Debian de test en `0660` (28 oct.). [Mediatheques.md](Mediatheques.md)
- ✅ Prowlarr : LXC 105 `servarr`, `<ip-servarr>:9696`, **2.7.0.5723**, compte `utilisateur` (28 oct.). [Mediatheques.md](Mediatheques.md)
- ✅ Sonarr : même CT, `<ip-servarr>:8989`, **4.0.20.3014**. *Cold Case* reconnue, 178,9 Gio (28 oct.). [Mediatheques.md](Mediatheques.md)
- ✅ Radarr : même CT, `<ip-servarr>:7878`, **6.4.4.10685**. *American History X* **Downloaded**, 1,9 Gio (28 oct.). [Mediatheques.md](Mediatheques.md)
- ✅ Bazarr : même CT, `<ip-servarr>:6767`, **v1.6.2**. Sonarr et Radarr reliés, profil `français`, pas de fournisseur (29 oct.). [Mediatheques.md](Mediatheques.md)
- ✅ Recyclarr : même CT, binaire **v8.8.1**, pas d'interface. Profils MULTi.VO créés, non assignés (1er nov.). [Mediatheques.md](Mediatheques.md)
- ✅ Lidarr : même CT, `<ip-servarr>:8686`, **3.1.6.5079**. `sons/` importé, pas de recherche (1er nov.). [Mediatheques.md](Mediatheques.md)
- ⬜ Navidrome retenu (1er nov.), pas installé. Tunnel sans Access. [Mediatheques.md](Mediatheques.md#navidrome-et-portail--choix-1er-nov)
- ⬜ Page de liens des interfaces *arr, chaque nom derrière Access. Pas joué. [Cloudflare.md](Cloudflare.md#visé-1er-nov-pas-joué)
- ✅ POC `tank/vmdata` (2026-10-06 ; nettoyé)
- ✅ Migration Vaultwarden vers `tank` (2026-10-14, [ADR-008](ADR/ADR-008-Vaultwarden-tank.md))
- ✅ `ADMIN_TOKEN` en Argon2 PHC (2026-10-17)
- ✅ Sauvegardes Vaultwarden : tars auto 20 et 21 oct. (k3s-01 + pve)
- ✅ Restore technique isolée (SQLite, Pod, HTTP 200) — [Vaultwarden.md](Vaultwarden.md#test-du-20-octobre-2026-technique)
- ✅ Restore fonctionnel isolé (login + 2FA + coffre, 2026-10-21)
- ✅ Snapshots zvol Vaultwarden horaires (12:00 et 13:00 le 21 oct.)
- ⬜ Premier snapshot quotidien timer (22 oct. 04:00) + rétention 24/7
- ⬜ Reprise réelle zvol (procédure écrite) + rétention Restic
