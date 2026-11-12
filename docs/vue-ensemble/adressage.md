# Plan d'adressage

Ce document est la **source de vérité** des adresses IP du homelab. Toutes les machines vivent sur le réseau domestique `<réseau-lan>`, derrière la box. Les serveurs ont une adresse fixe. Les postes utilisateurs restent en DHCP.

## 1. Adresses en service

| Adresse | Machine | ID Proxmox | Rôle |
| --- | --- | --- | --- |
| `<ip-box>` | Box | — | Passerelle et DNS du réseau domestique |
| `<ip-cloudflare>` | LXC `cloudflare` | CT 100 | Tunnel Cloudflare |
| `<ip-wireguard>` | LXC `wireguard` | CT 115 | Passerelle WireGuard du téléphone |
| `<ip-k3s-01>` | VM `k3s-01` | VM 101 | Cluster K3s, Traefik sur le port 80 |
| `<ip-samba>` | LXC `samba` | CT 102 | Partages SMB pour le LAN |
| `<ip-pve>` | Proxmox `pve` | — | Hyperviseur |
| `<ip-jellyfin>` | LXC `jellyfin` | CT 103 | Jellyfin, port 8096 |
| `<ip-qbittorrent>` | LXC `qbittorrent` | CT 104 | qBittorrent, port 8080 |
| `<ip-servarr>` | LXC `servarr` | CT 105 | Prowlarr, Sonarr, Radarr, Bazarr, Lidarr, Recyclarr |
| `<ip-navidrome>` | LXC `navidrome` | CT 106 | Navidrome, port 4533 |
| `<ip-runner>` | LXC `runner` | CT 107 | Runner Gitea Actions |
| `<ip-lan>` | LXC `lan` | CT 116 | Noms et HTTPS sur le LAN (Traefik) |

## 2. Détail par machine

### `cloudflare` — CT 100

Ce conteneur fait tourner `cloudflared`, qui ouvre le tunnel sortant vers Cloudflare. Il ne reçoit aucune connexion entrante depuis Internet. Voir [cloudflare.md](../exploitation/cloudflare.md).

### `wireguard` — CT 115

Cette passerelle est en service depuis le 9 nov. 2026. Elle permet au téléphone de joindre tous les services du LAN hors du Wi-Fi. C'est désormais le seul accès distant, à part la route publique de Vaultwarden.

- Adresse du téléphone dans le tunnel : `<ip-wg-téléphone>/32`.
- Le PC fixe n'a pas de clé WireGuard.
- Le conteneur sert aussi la **page des services** (portail « Labo ») : `https://<ip-wireguard>/`, avec un certificat local, et en HTTP sur le port 80. C'est une page statique, installable sur le téléphone (manifeste web et icônes), qui regroupe les liens vers les services du LAN. Elle est servie par `portail.py` et déployée par le rôle Ansible `wireguard`.
- Le conteneur sert aussi le DNS du téléphone : dnsmasq écoute sur `<ip-wg-serveur>`, l'adresse du 115 dans le tunnel, et transmet à la box.
- La box porte une seule règle d'ouverture, en IPv6 : UDP 51820 vers l'adresse globale du CT 115. Cette adresse IPv6 n'est volontairement pas écrite dans la documentation. Aucune redirection IPv4 n'existe.

### `k3s-01` — VM 101

Cette VM porte le cluster K3s. Traefik y reçoit le trafic HTTP sur le port 80. Voir [kubernetes.md](../concepts/kubernetes.md).

### `samba` — CT 102

Ce conteneur publie les partages SMB du LAN. Il est en service dans cette configuration depuis le 24 oct. 2026. Voir [samba.md](../exploitation/samba.md).

### `jellyfin` — CT 103

Jellyfin écoute sur le port 8096. Il est en service depuis le 28 oct. 2026, et se joint par le LAN ou par WireGuard. Il n'a pas de route publique. Voir [jellyfin.md](../exploitation/mediatheques/jellyfin.md).

### `qbittorrent` — CT 104

qBittorrent écoute sur le port 8080. Il se joint par le LAN ou par WireGuard, et n'a pas de route publique. Depuis le 29 oct. 2026, le trafic du client sort par Proton VPN. L'ancienne configuration Mullvad est conservée dans `wg0.conf.mullvad`. Voir [qbittorrent-vpn.md](../exploitation/mediatheques/qbittorrent-vpn.md).

### `servarr` — CT 105

Ce conteneur regroupe les outils de gestion des médiathèques. Leurs interfaces se joignent par le LAN ou par WireGuard. Du 2 au 10 nov. 2026, cinq d'entre elles étaient aussi publiées sur Internet derrière Cloudflare Access ; ces routes sont désactivées. Voir [servarr.md](../exploitation/mediatheques/servarr.md).

| Outil | Port | Version | Installé le |
| --- | --- | --- | --- |
| Prowlarr | 9696 | 2.7.0.5723 | 28 oct. 2026 |
| Sonarr | 8989 | 4.0.20.3014 | 28 oct. 2026 |
| Radarr | 7878 | 6.4.4.10685 | 28 oct. 2026 |
| Bazarr | 6767 | v1.6.2 | 29 oct. 2026 |
| Lidarr | 8686 | 3.1.6.5079 | 1er nov. 2026 |

### `navidrome` — CT 106

Navidrome 0.64.2 écoute sur le port 4533 et lit la musique en lecture seule. Il se joint par le LAN ou par WireGuard. Sa route publique `navidrome.labo.example`, ouverte sans Access le 2 nov. 2026, est désactivée. Voir [navidrome.md](../exploitation/mediatheques/navidrome.md).

### `runner` — CT 107

Ce conteneur exécute les jobs de Gitea Actions. Il a été créé le 4 nov. 2026, non privilégié, avec 2 Gio de RAM et 16 Go de disque. Il ne monte pas `tank`, pour ne jamais voir les données. Le runner `gitea-runner` `v5.2.0` porte l'étiquette `host`. Voir [forge-gitea.md](../exploitation/forge-gitea.md).

### `lan` — CT 116

Ce conteneur est en service depuis le 12 nov. 2026. Traefik y porte le certificat joker `*.lan.labo.example` et relaie chaque nom vers son service. L'enregistrement public `*.lan.labo.example` pointe vers `<ip-lan>`. Cette adresse n'est pas joignable depuis Internet. Voir [noms-lan.md](../exploitation/noms-lan.md).

## 3. Adresses réservées aux essais

Chaque LXC est d'abord recréé par Ansible sur un conteneur d'essai, avant de toucher au conteneur en service. Le conteneur d'essai prend l'adresse du conteneur en service **plus un**. Ces conteneurs ont été retirés après l'essai, mais relancer leur playbook les recréerait aux mêmes adresses. Voir l'[ADR-010](../decisions/ADR-010-Ansible-LXC.md).

| Adresse | Conteneur d'essai | Copie de |
| --- | --- | --- |
| `<ip-cloudflare-ct114>` | CT 114 `cloudflare-essai` | CT 100 |
| `<ip-samba-ct111>` | CT 111 `samba-essai` | CT 102 |
| `<ip-jellyfin-ct110>` | CT 110 `jellyfin-essai` | CT 103 |
| `<ip-qbittorrent-ct113>` | CT 113 `qbittorrent-essai` | CT 104 |
| `<ip-servarr-ct112>` | CT 112 `servarr-essai` | CT 105 |
| `<ip-navidrome-ct109>` | CT 109 `navidrome-essai` | CT 106 |
| `<ip-runner-ct108>` | CT 108 `runner-essai` | CT 107 |
| `<ip-lan-essai>` | aucun conteneur d'essai | CT 116 |

## 4. Adresses abandonnées

`<ip-pve-prévue>` était prévue à l'origine pour Proxmox. Elle n'a jamais été appliquée.

## 5. Procédure : attribuer une adresse à une nouvelle machine

**Prérequis**

- Le besoin de la machine est établi. Rien n'est créé « au cas où » (voir [architecture.md](architecture.md)).
- Ce document est ouvert et à jour.

**Action**

1. Choisir la prochaine dizaine libre (`.110`, `.120`…) pour la machine en service. Garder la dizaine plus un pour son conteneur d'essai.
2. Inscrire l'adresse, la machine, son ID Proxmox et son rôle dans le tableau de la section 1.
3. Créer la machine avec cette adresse fixe.

**Vérification**

- Avant la création, `ping -c 2 <adresse>` ne répond pas : l'adresse est libre.
- Après la création, la machine répond au `ping` et l'adresse figure dans ce document.
