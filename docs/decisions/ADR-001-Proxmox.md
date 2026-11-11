# ADR-001 — Hyperviseur : Proxmox VE

## Statut

Accepté. Appliqué dès l'installation du serveur (août 2026).

## Contexte

Le homelab doit héberger plusieurs services indépendants les uns des autres. La liste envisagée au départ :

- Home Assistant ;
- Docker ;
- Jellyfin ;
- la stack *arr ;
- de l'IA locale ;
- des services à venir.

Le projet a aussi un objectif pédagogique et professionnel : la plateforme choisie doit être celle qu'on rencontre en entreprise.

## Décision

Utiliser **Proxmox VE** comme hyperviseur principal.

## Raisons

- Isolation des services, dans des machines virtuelles ou des conteneurs LXC.
- Snapshots et sauvegardes intégrés.
- Administration par une interface web.
- Forte adoption, en entreprise comme dans les homelabs.

## Alternatives étudiées

- Debian
- Ubuntu Server
- TrueNAS SCALE

La décision d'origine ne détaille pas pourquoi chacune a été écartée. Les raisons ci-dessus, en faveur de Proxmox, sont celles qui ont été écrites.

## Conséquences

- Toute l'infrastructure est construite au-dessus de Proxmox.
- Les données sont stockées sur un miroir ZFS distinct du système (voir l'[ADR-002](ADR-002-ZFS.md)).
- **Dépôts** : on utilise le dépôt **Proxmox No-Subscription**, gratuit, adapté à un homelab et largement utilisé. Le dépôt Enterprise, réservé aux installations sous souscription, est désactivé.
- **Mises à jour** : la plateforme a été entièrement mise à jour avant le déploiement des premiers services. Le but est de partir d'une base saine, de corriger les failles connues et d'éviter de changer de version en pleine construction.
- L'installation de Proxmox reste un mode opératoire manuel. Ansible ne la reproduit pas (voir l'[ADR-010](ADR-010-Ansible-LXC.md)).

Exploitation : [proxmox.md](../exploitation/proxmox.md).
