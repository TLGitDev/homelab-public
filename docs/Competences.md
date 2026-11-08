# Compétences

> Ce document recense les compétences acquises au cours du projet Homelab.
>
> Une compétence est considérée comme acquise lorsque je suis capable :
>
> - d'expliquer le concept ;
> - de le mettre en œuvre ;
> - de diagnostiquer un problème courant.

> Une compétence n'est pas validée parce qu'une manipulation a été réalisée une fois. Elle est validée lorsque je suis capable de reproduire la démarche, d'expliquer le fonctionnement et de diagnostiquer un problème courant sans suivre un tutoriel.

Relevé au **5 nov. 2026**, après les phases 0 à 5. Les niveaux du tableau n'ont pas été revus pour l'alerte : elle est en place, pas encore notée comme compétence acquise. Le détail des jalons est dans [FeuilleDeRoute.md](FeuilleDeRoute.md). L'état installé est dans [Architecture.md](Architecture.md).

---

# Niveau de maîtrise

| Niveau | Signification |
|---------|---------------|
| 🔲 | Pas encore abordé |
| 🟡 | Compris mais nécessite de l'aide |
| 🟢 | Autonome |
| 🔵 | Capable d'expliquer à quelqu'un d'autre |

---

# Matériel

| Compétence | Niveau |
|------------|--------|
| Assemblage d'un PC | 🟢 |
| Installation d'un processeur AM4 | 🟢 |
| Installation d'un ventirad | 🟢 |
| Application / compréhension de la pâte thermique | 🟢 |
| Installation de mémoire DDR4 | 🟢 |
| Compréhension du Dual Channel | 🟢 |
| Installation d'un SSD NVMe | 🟢 |
| Différence NVMe / SATA | 🟢 |
| Installation de disques SATA | 🟢 |
| Câblage d'une alimentation ATX | 🟢 |
| Câblage SATA (données / alimentation) | 🟢 |
| Montage d'une carte mère | 🟢 |
| Cable Management | 🟡 |
| Lecture du BIOS UEFI | 🟢 |
| Bench Test | 🟢 |
| Diagnostic matériel | 🟢 |

---

# Système

| Compétence | Niveau |
|------------|--------|
| Installation de Proxmox | 🟢 |
| Réinstallation du système sur ZFS | 🟢 |
| Architecture Proxmox | 🟢 |
| Gestion des dépôts APT | 🟢 |
| Mise à jour d'un hyperviseur | 🟡 |
| Gestion des mises à jour | 🟢 |
| Gestion des services systemd | 🟢 |
| Timers systemd | 🟢 |
| Comptes et groupes Linux | 🟢 |
| Scripts d'exploitation (Git ≠ fichiers installés) | 🟢 |

---

# Virtualisation

| Compétence | Niveau |
|------------|--------|
| Hyperviseur | 🟢 |
| Machine virtuelle (disques, réseau, `fstab`) | 🟢 |
| Conteneur LXC | 🟢 |
| LXC non privilégié | 🟢 |
| idmap (UID / GID hôte dans le CT) | 🟢 |
| Montage hôte → CT (lecture seule ou écriture) | 🟢 |
| Pare-feu d'un conteneur | 🟢 |
| Choisir VM, LXC ou K3s selon le besoin | 🟢 |
| Snapshots de VM Proxmox | 🔲 |
| Sauvegardes de l'hyperviseur (vzdump) | 🔲 |
| Architecture de la virtualisation | 🟢 |

---

# Stockage

| Compétence | Niveau |
|------------|--------|
| Architecture ZFS (`rpool` / `tank`) | 🟢 |
| Pool | 🟢 |
| VDEV (choix figé à la création) | 🟢 |
| Miroir ZFS | 🟢 |
| Dataset (un usage, un dataset) | 🟢 |
| zvol (volume bloc, ext4, UUID) | 🟢 |
| Checksums | 🟡 |
| Self-healing | 🟡 |
| Scrub | 🟡 |
| S.M.A.R.T | 🟡 |
| Remplacement d'un disque | 🔲 |
| Quota | 🔲 |

---

# Sauvegardes

| Compétence | Niveau |
|------------|--------|
| RAID ≠ snapshot ≠ sauvegarde | 🟢 |
| RPO / RTO | 🟢 |
| Snapshot ZFS (timer, rétention horaire) | 🟢 |
| Rollback d'un snapshot sur la prod | 🔲 |
| Archive tar cohérente (service arrêté, SHA-256) | 🟢 |
| Copie USB chiffrée (Restic) | 🟢 |
| Restauration isolée (coffre, fichier, forge, runner) | 🟢 |
| Reprise sur le volume de production | 🔲 |
| Rétention longue (Restic, snapshots quotidiens) | 🟡 |
| Configs sauvegardées à part des médias | 🟢 |

---

# Données

| Compétence | Niveau |
|------------|--------|
| Sync ≠ archive ≠ sauvegarde | 🟢 |
| Inventaire par catégorie | 🟢 |
| Partage SMB (LXC, LAN seulement) | 🟢 |
| Droits de fichiers (groupe, mode) | 🟢 |
| Vérification d'une copie (SHA-256) | 🟢 |

Phase 2 (téléphone) close le 25 oct. (document privé).

| Compétence | Niveau |
|------------|--------|
| Export par type de donnée | 🟢 |
| Restauration sur un autre téléphone | 🟡 |

---

# Docker

Les applications du cluster consomment des images. Le moteur Docker n'est pas le mode d'exploitation (le runner CI est hors de `k3s-01`, sans socket Docker).

| Compétence | Niveau |
|------------|--------|
| Docker | 🟡 |
| Image de conteneur | 🟡 |
| Docker Compose | 🔲 |
| Volumes | 🔲 |
| Réseaux Docker | 🔲 |
| Mise à jour de conteneurs | 🔲 |

---

# Kubernetes

Cours : [Kubernetes.md](Kubernetes.md). En service : K3s, Traefik, Argo CD, Vaultwarden, Gitea.

| Compétence | Niveau |
|------------|--------|
| Pourquoi Kubernetes (vs Linux / Docker) | 🟢 |
| Modèle déclaratif | 🟢 |
| Réconciliation | 🟢 |
| API Server | 🟡 |
| Pod | 🟢 |
| Deployment / ReplicaSet | 🟢 |
| OwnerReferences | 🟡 |
| Service | 🟢 |
| Service LoadBalancer | 🟢 |
| Selector | 🟢 |
| EndpointSlice | 🟡 |
| Labels | 🟢 |
| Taints / Tolerations | 🟡 |
| Ingress (Traefik, par nom d'hôte) | 🟢 |
| PVC / PV / StorageClass | 🟢 |
| Local PV statique (`Retain`) | 🟢 |
| ConfigMap / Secret | 🟢 |
| data / stringData | 🟢 |
| Sealed Secrets | 🟢 |
| SOPS / age | 🟡 |
| Namespace | 🟢 |
| Argo CD / GitOps | 🟢 |
| Sync manuelle et écart Git / cluster | 🟢 |
| Manifestes YAML | 🟢 |
| Rolling update / rollback GitOps | 🟢 |
| Cycle de vie des données (PVC) | 🟢 |
| Conception (besoin → ressource) | 🟢 |
| Docker → ressources K8s | 🟢 |
| Cluster (K3s, un nœud) | 🟢 |

---

# Git et forge

Décision et as-built : [Forge.md](Forge.md). Argo CD lit GitHub. `homelab` n'a pas de copie de travail sur Gitea.

| Compétence | Niveau |
|------------|--------|
| Git (commit, branche, remote) | 🟢 |
| Branche protégée | 🟡 |
| Demande de fusion | 🟡 |
| Comparer deux forges et trancher | 🟢 |
| Gitea (pod, SQLite, zvol dédié) | 🟡 |
| Runner isolé du coffre et du cluster | 🟢 |
| Workflow Actions | 🟡 |
| Miroir de dépôt | 🟡 |
| Secret de CI hors du dépôt | 🟢 |

---

# Médiathèques

As-built : [Mediatheques.md](Mediatheques.md). Jellyfin, qBittorrent, la pile *arr et Navidrome sont en service.

| Compétence | Niveau |
|------------|--------|
| Dataset partagé et groupe commun | 🟢 |
| Lecture seule ou écriture selon le service | 🟢 |
| Client BitTorrent isolé (montage, pare-feu) | 🟢 |
| VPN de sortie (WireGuard) | 🟡 |
| Chaîne indexeur → téléchargement → bibliothèque | 🟡 |
| Publication sélective (Access, ou public sans Access) | 🟢 |

---

# Réseau

| Compétence | Niveau |
|------------|--------|
| Adresse IP | 🟢 |
| Plan d'adressage | 🟢 |
| Configuration réseau Linux | 🟢 |
| Bridge Linux | 🟢 |
| Configuration DNS | 🟢 |
| Diagnostic DNS | 🟢 |
| Diagnostic réseau | 🟢 |
| Synchronisation NTP | 🟢 |
| Diagnostic NTP | 🟢 |
| Reverse proxy (Traefik) | 🟢 |
| Origine HTTP du tunnel, HTTPS chez Cloudflare | 🟢 |
| VLAN | 🔲 |
| NAT | 🔲 |
| WireGuard pour l'accès privé distant | 🔲 |

---

# Sécurité

| Compétence | Niveau |
|------------|--------|
| Pare-feu (CT et nftables) | 🟢 |
| Clés SSH | 🟡 |
| Cloudflare Tunnel | 🟢 |
| Cloudflare Access | 🟢 |
| MFA | 🟢 |
| Authentification | 🟢 |
| Gestion des accès | 🟢 |
| Secret hors Git (Sealed Secret, fichier en 600) | 🟢 |
| Hash Argon2id | 🟢 |
| API Kubernetes non publiée | 🟢 |

---

# Home Assistant

Hors phases. Pas commencé.

| Compétence | Niveau |
|------------|--------|
| Installation | 🔲 |
| Intégrations | 🔲 |
| Automatisations | 🔲 |
| MQTT | 🔲 |

---

# Administration

| Compétence | Niveau |
|------------|--------|
| Documentation d'infrastructure | 🟢 |
| Diagnostic | 🟢 |
| Dépannage | 🟢 |
| Diagnostic par hypothèses | 🟢 |
| Analyse de cause racine | 🟢 |
| Lecture des logs et messages système | 🟢 |
| Supervision | 🔲 |
| Alertes | 🔲 |
| Mises à jour et fenêtres de redémarrage | 🔲 |

---

# Architecture

| Compétence | Niveau |
|------------|--------|
| Compréhension des couches | 🟢 |
| Décisions d'architecture (ADR) | 🟢 |
| Documentation d'architecture | 🟢 |
| Séparation des responsabilités | 🟢 |
| Principe du moindre privilège | 🟢 |
| Organisation des services | 🟢 |
| Défense en profondeur | 🟢 |
| Refus par défaut | 🟢 |
| Exposition minimale | 🟢 |
| Validation d'une architecture | 🟢 |

# Objectif du projet

À la fin du projet, l'objectif est d'être capable de :

- Concevoir une infrastructure complète.
- Installer et administrer Proxmox.
- Comprendre le stockage ZFS.
- Déployer et maintenir plusieurs services.
- Sécuriser l'accès distant.
- Diagnostiquer les incidents courants.
- Documenter l'ensemble de l'infrastructure.
- Expliquer chaque décision technique prise.

Déjà en place : Proxmox, ZFS, K3s, Argo CD, coffre, données personnelles, téléphone, médiathèques, forge d'essai, forge tenable (phase 6, 6 nov.), alerte de sauvegarde (phase 5, 5 nov.), runner reconstruit par Ansible (phase 7, 7 nov.), Navidrome d'essai (phase 8, 8 nov., récit sur le 106), Jellyfin d'essai (phase 8, 8 nov., récit sur le 103), Samba d'essai (phase 8, 8 nov., récit sur le 102), servarr d'essai (phase 8, 8 nov., récit sur le 105), qBittorrent d'essai (phase 8, 8 nov., récit sur le 104), Cloudflare d'essai (phase 8, 8 nov., récit sur le 100). Encore ouverts : exploitation (phase 9), dépôt public (phase 10), site (phase 11), remplacement de disque, rollback snapshot sur la prod, reprise réelle du coffre sur son zvol.

Les définitions (hyperviseur, LXC, ZFS, CIDR, etc.) sont dans [Glossaire.md](Glossaire.md).

# Évolution

Ce document est mis à jour à la fin de chaque grande étape du projet.

Le niveau d'une compétence peut évoluer :

🔲 → 🟡 → 🟢 → 🔵

L'objectif n'est pas de tout passer en 🔵, mais d'être autonome (🟢) sur les technologies utilisées dans le homelab.
