# Documentation du homelab

Cette documentation décrit la conception, la réalisation et l'exploitation d'un homelab personnel. Elle sert à deux choses : retrouver comment chaque élément a été construit, et pouvoir le reconstruire.

Chaque étape suit le même cycle :

> Comprendre → Faire → Vérifier → Documenter

Aucune modification importante n'est faite sans comprendre le problème qu'elle résout. Présentation du dépôt : [README.md](../README.md) à la racine.

## 1. Le homelab en une minute

Un seul serveur physique, `pve` (`<ip-pve>`), fait tourner Proxmox VE sur ZFS :

- le système et les disques des machines sont sur le NVMe (`rpool`) ;
- les données sont sur un miroir de deux disques de 8 To (`tank`).

Les services légers vivent chacun dans un conteneur LXC : un service, un LXC. Les applications tournent sur un cluster K3s à un nœud (VM `k3s-01`, `<ip-k3s-01>`), déployé en GitOps par Argo CD. Les nouvelles applications se poussent sur la forge Gitea, qui les recopie vers GitHub ; Argo CD déploie depuis GitHub.

Depuis Internet, seul Vaultwarden est publié, par un tunnel Cloudflare. Tout le reste se joint sur le LAN, ou depuis le téléphone par WireGuard. Les sauvegardes combinent des archives quotidiennes, des snapshots ZFS et un disque USB géré avec Restic. Une alerte arrive sur le téléphone en cas d'échec.

## 2. Par où commencer

| Pour… | Lire |
| --- | --- |
| Comprendre l'ensemble | [architecture.md](vue-ensemble/architecture.md) |
| Savoir ce qui reste à faire | [FeuilleDeRoute.md](FeuilleDeRoute.md) |
| Savoir pourquoi un choix a été fait | [Les décisions (ADR)](decisions/README.md) |
| Retrouver ce qui s'est passé, et quand | [Le journal](projet/journal/README.md) |
| Réparer ou reconstruire quelque chose | [restauration.md](exploitation/restauration.md) |

## 3. Plan de la documentation

### Vue d'ensemble — `vue-ensemble/`

Ce qui existe, et comment c'est relié.

| Fichier | Contenu |
| --- | --- |
| [architecture.md](vue-ensemble/architecture.md) | Principes, réseau, où tourne quoi, exposition des services, état des lieux |
| [materiel.md](vue-ensemble/materiel.md) | Composants du serveur, disques, câblage, entretien |
| [adressage.md](vue-ensemble/adressage.md) | Plan d'adresses IP, identifiants des conteneurs et des VM |

### Exploitation — `exploitation/`

Comment chaque élément est installé, vérifié et entretenu. Les procédures suivent le format **Prérequis → Action → Vérification**.

| Fichier | Contenu |
| --- | --- |
| [proxmox.md](exploitation/proxmox.md) | Le nœud `pve` : accès, réseau, scripts et timers installés |
| [stockage-zfs.md](exploitation/stockage-zfs.md) | Les pools `rpool` et `tank`, les datasets, les zvols |
| [sauvegardes.md](exploitation/sauvegardes.md) | La chaîne de sauvegarde, Restic sur USB, l'alerte ntfy |
| [restauration.md](exploitation/restauration.md) | Les scénarios de reprise, testés ou seulement écrits |
| [cloudflare.md](exploitation/cloudflare.md) | Le tunnel, Access, les routes publiées et retirées |
| [vaultwarden.md](exploitation/vaultwarden.md) | Le gestionnaire de mots de passe dans K3s |
| [forge-gitea.md](exploitation/forge-gitea.md) | La forge Gitea, son runner et la CI |
| [samba.md](exploitation/samba.md) | Le partage SMB du LAN |
| [ansible.md](exploitation/ansible.md) | Les LXC décrits en Ansible, et leurs essais |
| [noms-lan.md](exploitation/noms-lan.md) | Les noms `*.lan.labo.example`, Traefik et le certificat joker |
| [mediatheques/](exploitation/mediatheques/README.md) | Films, séries et musique : [Jellyfin](exploitation/mediatheques/jellyfin.md), [qBittorrent et VPN](exploitation/mediatheques/qbittorrent-vpn.md), [les *arr](exploitation/mediatheques/servarr.md), [Navidrome](exploitation/mediatheques/navidrome.md) |

### Décisions — `decisions/`

Un ADR par décision d'architecture, de l'hyperviseur (ADR-001) au choix entre LXC et K3s (ADR-012). L'index et leur statut sont dans [decisions/README.md](decisions/README.md).

### Concepts — `concepts/`

Les notions nécessaires pour lire le reste, expliquées pour ce homelab.

| Fichier | Contenu |
| --- | --- |
| [zfs.md](concepts/zfs.md) | Pools, datasets, zvols, snapshots, miroir |
| [kubernetes.md](concepts/kubernetes.md) | Les objets Kubernetes, et leur usage ici |
| [argocd.md](concepts/argocd.md) | Le GitOps, le modèle App of Apps, les procédures Argo CD |
| [glossaire.md](concepts/glossaire.md) | Les définitions |

### Projet — `projet/` et feuille de route

Le suivi du travail.

| Fichier | Contenu |
| --- | --- |
| [FeuilleDeRoute.md](FeuilleDeRoute.md) | Les phases 0 à 18, dans l'ordre de travail, avec leurs jalons |
| [journal/](projet/journal/README.md) | Le récit des séances, un fichier par mois |
| [competences.md](projet/competences.md) | Les niveaux de maîtrise par domaine |

### Données personnelles — `prive/`

Ces pages concernent les données personnelles et le téléphone. Elles sont rangées à part pour pouvoir être exclues de la future version publique du dépôt.

| Fichier | Contenu |
| --- | --- |
| (document privé) | L'inventaire des données personnelles, et leur place sur `tank` |
| (document privé) | La sauvegarde du téléphone, et la remise en service d'un nouveau téléphone |

## 4. Conventions d'écriture

- **Une page décrit l'état actuel.** Les dates et le récit vont dans le [journal](projet/journal/README.md). Les ADR gardent leur historique dans une section « Révisions ».
- **« As-built »** désigne ce qui est réellement en place, par opposition à la cible décrite dans la feuille de route.
- **Les secrets n'apparaissent jamais** : ni les mots de passe, ni les clés privées, ni les jetons. Une page indique seulement où ils se trouvent.
- **Une procédure ne se valide pas sur parole.** Chaque étape a sa vérification, et un test n'est daté que s'il a réellement été joué.
- **Un fichier dans Git n'est pas un fichier installé.** Les sources de `infrastructure/` doivent être copiées sur la machine. Chaque page d'exploitation indique où.
