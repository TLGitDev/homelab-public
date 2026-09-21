# Proxmox VE

## Installation

Version : (à compléter)

Nœud : `pve`

Support système :

- SSD NVMe WD Black SN7100 2 To
- Système de fichiers : **ZFS** (`rpool`)

Le nœud a d'abord été installé en ext4 + LVM-Thin, puis réinstallé sur ZFS le 2026-09-02 (voir [Journal.md](Journal.md) et [ADR-002](ADR/ADR-002-ZFS.md)).

## Réseau

Adresse IP :
`<ip-pve>/24`

Passerelle :
`<ip-box>`

DNS :
`<ip-box>`

Accès Web :

https://<ip-pve>:8006

Authentification :

Utilisateur : `root`

Realm : Linux PAM

Accès distant : `proxmox.labo.example` via Cloudflare Tunnel + Access (aucun port ouvert sur le routeur).

## Plan d'adressage

Source de vérité pour les IP du homelab.

| Adresse | Service | Notes |
|---------|---------|-------|
| `<ip-box>` | Box / passerelle / DNS | Réseau domestique |
| `<ip-pve-prévue>` | — | Adresse initialement prévue pour Proxmox, **jamais appliquée** |
| `<ip-cloudflare>` | LXC `cloudflare` (CT 100) | Tunnel Cloudflare |
| `<ip-pve>` | Proxmox (`pve`) | Adresse réelle du nœud |

## Particularités

- Installation réalisée via Rufus.
- Installation UEFI.
- Interface Web validée.
- Réinstallation sur ZFS avant hébergement de données critiques.

# Architecture

## Hiérarchie

```
Datacenter
└── Node (pve)
    ├── rpool (ZFS, NVMe)
    └── tank (ZFS, miroir HDD)
```

## Stockage

- `rpool` : infrastructure (Proxmox, VM, LXC) sur le NVMe.
- `tank` : données, miroir des deux IronWolf. Aucun dataset de service pour l'instant.

Détail : [Stockage.md](Stockage.md).

## Dépôts

- Debian
- Debian Security
- Proxmox No-Subscription

Dépôts Enterprise désactivés.

## Synchronisation du temps

Service utilisé : Chrony

Synchronisation NTP validée.

## systemd

Les services Linux sont gérés par systemd.

Commandes principales :

```
systemctl status
systemctl start
systemctl stop
systemctl restart
systemctl enable
systemctl disable
```

Exemple : `systemctl status cloudflared`

Permet d'observer : état du service, PID, mémoire, CPU, journaux.

Le démon `cloudflared` tourne dans le LXC `cloudflare`, pas sur l'hyperviseur. Voir [Cloudflare.md](Cloudflare.md).

## Bonnes pratiques

Avant toute évolution importante :

- vérifier les mises à jour ;
- vérifier l'état SMART des disques ;
- vérifier l'espace disque disponible ;
- vérifier les sauvegardes.

Sauvegardes : [Sauvegardes.md](Sauvegardes.md).
