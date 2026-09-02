# ADR-001 — Choix de Proxmox VE

## Statut

Accepté

## Contexte

Le homelab doit héberger plusieurs services indépendants :

- Home Assistant
- Docker
- Jellyfin
- Stack *arr*
- IA locale
- Services futurs

Le projet a également un objectif pédagogique et professionnel.

## Décision

Utiliser Proxmox VE comme hyperviseur principal.

## Raisons

- Isolation des services.
- Création de machines virtuelles.
- Conteneurs LXC.
- Snapshots.
- Sauvegardes intégrées.
- Interface Web.
- Forte adoption en entreprise et dans les homelabs.

## Alternatives étudiées

- Debian
- Ubuntu Server
- TrueNAS SCALE

## Conséquences

Toute l'infrastructure sera construite au-dessus de Proxmox.
Les données seront stockées sur un miroir ZFS distinct.

## Décisions prises

### Dépôts

Choix du dépôt **Proxmox No-Subscription**.

Justification :

- adapté à un homelab ;
- gratuit ;
- largement utilisé par la communauté.

Le dépôt Enterprise est réservé aux environnements de production disposant d'une souscription.

### Mise à jour

La plateforme est entièrement mise à jour avant le déploiement des premiers services.

Objectif :

- disposer d'une base saine ;
- corriger les éventuelles failles de sécurité ;
- éviter les migrations de version pendant la construction du homelab.