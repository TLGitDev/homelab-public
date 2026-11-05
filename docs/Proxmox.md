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
| `<ip-k3s-01>` | K3s (Traefik :80) | Cluster applicatif |
| `<ip-samba>` | LXC `samba` (CT 102) | SMB LAN (as-built 24 oct.) |
| `<ip-pve>` | Proxmox (`pve`) | Adresse réelle du nœud |
| `<ip-jellyfin>` | LXC `jellyfin` (CT 103) | LAN, port 8096. En service le 28 oct. Access : plus tard. [Mediatheques.md](Mediatheques.md#jellyfin--décision-28-oct) |
| `<ip-qbittorrent>` | LXC `qbittorrent` (CT 104) | LAN, port 8080. Proton VPN pour le compte du client (29 oct.). Mullvad gardé dans `wg0.conf.mullvad`. [Mediatheques.md](Mediatheques.md#proton--décision-29-oct) |
| `<ip-servarr>` | LXC `servarr` (CT 105) | Prowlarr 2.7.0.5723 (9696), Sonarr 4.0.20.3014 (8989), Radarr 6.4.4.10685 (7878), 28 oct. Bazarr v1.6.2 (6767), 29 oct. Lidarr 3.1.6.5079 (8686), 1er nov. Public avec Access (2 nov.) : `prowlarr`, `sonarr`, `radarr`, `lidarr`, `bazarr`. [Mediatheques.md](Mediatheques.md#navidrome-et-portail--choix-1er-nov) |
| `<ip-navidrome>` | LXC `navidrome` (CT 106) | Port 4533, lecture seule, 0.64.2. Public `navidrome.labo.example`, sans Access (2 nov.). [Mediatheques.md](Mediatheques.md#navidrome--décision-2-nov) |
| `<ip-runner>` | LXC `runner` (CT 107) | Créé le 4 nov., non privilégié, 2 Gio, 16 Go. Sans montage de `tank`. `gitea-runner` `v5.2.0`, étiquette `host`, vu Idle. [Forge.md](Forge.md#décision) |

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
- `tank` : données, miroir des deux IronWolf. Volumes VM sous `tank/vmdata` (Vaultwarden : `vm-101-vaultwarden-data`). Détail : [Stockage.md](Stockage.md).

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

---

# Exploitation

Scripts et units `pve` : [`infrastructure/pve/`](../infrastructure/pve/). Git = référence versionnée. Actif : `/usr/local/sbin/` et `/etc/systemd/system/`. Un commit ne déploie pas. Après copie : permissions, syntaxe, test.

Ne jamais versionner clé SSH privée, mot de passe Restic, ni archive.

| Rôle | Installé | Git |
|------|----------|-----|
| Pull Vaultwarden | `/usr/local/sbin/pull-vaultwarden-backup.sh` | [`scripts/pull-vaultwarden-backup.sh`](../infrastructure/pve/scripts/pull-vaultwarden-backup.sh) |
| Timer pull | 03:15 | [`systemd/pull-vaultwarden-backup.*`](../infrastructure/pve/systemd/) |
| USB / Restic | `/usr/local/sbin/backup-usb` (**manuel**) | [`scripts/backup-usb`](../infrastructure/pve/scripts/backup-usb) |
| Snapshots zvol VW | `/usr/local/sbin/snapshot-vaultwarden-zvol.sh` (horaire + 04:00) | [`scripts/snapshot-vaultwarden-zvol.sh`](../infrastructure/pve/scripts/snapshot-vaultwarden-zvol.sh) |
| Alerte ntfy | pas installé | [`scripts/notify-ntfy`](../infrastructure/pve/scripts/notify-ntfy) |
| Contrôle quotidien | pas installé, 08:15 | [`scripts/check-sauvegardes.sh`](../infrastructure/pve/scripts/check-sauvegardes.sh) |
| Scrub `tank` | pas installé, 1er dimanche 05:00 | [`systemd/scrub-tank.timer`](../infrastructure/pve/systemd/scrub-tank.timer) |
| Samba (LAN) | LXC `samba` CT 102 / `smbd` (plus sur `pve`) | [`samba/smb.conf`](../infrastructure/pve/samba/smb.conf) |

Pull : SSH/SCP, clé `/root/.ssh/id_ed25519_backup_k3s`, SHA-256, `tar -tf`, pas d'écrasement si hash différent, 7 archives. Premier tar auto confirmé : `vaultwarden-2026-10-20_030012.tar`. Détail : [Vaultwarden.md](Vaultwarden.md#pve--0315).

USB : Restic de `/tank/backups` + dossiers perso live (script Git 24 oct.). Configs médiathèques dans le snapshot `<snapshot>` (2 nov.). [Sauvegardes.md](Sauvegardes.md#configs-médiathèques-2-nov).

SMB : LXC `samba` (`<ip-samba>`), cinq partages, user `utilisateur`, pas Internet. (document privé).
