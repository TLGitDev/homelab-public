# Compétences

Ce document mesure ce que le projet m'a appris, domaine par domaine. Il sert à suivre la progression, et à préparer les entretiens : chaque ligne doit pouvoir être expliquée et démontrée.

**Une compétence est acquise** quand je sais l'expliquer, la mettre en œuvre et diagnostiquer un problème courant, sans tutoriel. L'avoir faite une fois ne suffit pas.

Relevé au **5 nov. 2026**, après les phases 0 à 5. Les niveaux n'ont pas été revus depuis : voir la section « Points à réévaluer » en fin de document. Les jalons sont dans la [feuille de route](../FeuilleDeRoute.md), l'état installé dans [architecture.md](../vue-ensemble/architecture.md).

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

Cours : [kubernetes.md](../concepts/kubernetes.md). En service : K3s, Traefik, Argo CD, Vaultwarden, Gitea.

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

Décision et as-built : [forge-gitea.md](../exploitation/forge-gitea.md). Argo CD lit GitHub. `homelab` n'a pas de copie de travail sur Gitea.

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

As-built : [médiathèques](../exploitation/mediatheques/README.md). Jellyfin, qBittorrent, la pile *arr et Navidrome sont en service.

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
| WireGuard pour l'accès privé distant | 🟡 |

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

À la fin du projet, je veux être capable de :

- concevoir une infrastructure complète ;
- installer et administrer Proxmox ;
- comprendre le stockage ZFS ;
- déployer et maintenir plusieurs services ;
- sécuriser l'accès distant ;
- diagnostiquer les incidents courants ;
- documenter l'ensemble de l'infrastructure ;
- expliquer chaque décision technique prise.

## Ce qui est en place

| Phase | Réalisation | Date |
| --- | --- | --- |
| 0 à 2 | Proxmox, ZFS, K3s, Argo CD, coffre, données personnelles, sauvegarde du téléphone | Jusqu'au 25 oct. 2026 |
| 3 | Forge Gitea, runner isolé, miroir GitHub | 3 et 4 nov. 2026 |
| 4 | Médiathèques : Jellyfin, qBittorrent, *arr, Navidrome | 28 oct. au 2 nov. 2026 |
| 5 | Alerte de sauvegarde (ntfy) | 5 nov. 2026 |
| 6 | Forge tenable (sauvegarde, CI des manifestes) | 6 nov. 2026 |
| 7 | Runner reconstruit par Ansible (essai sur le CT 108) | 7 nov. 2026 |
| 8 | Navidrome, Jellyfin, Samba, servarr, qBittorrent et Cloudflare recréés par Ansible sur des conteneurs d'essai (CT 109 à 114) ; les conteneurs en service (100 à 106) restent ceux créés à la main | 8 nov. 2026 |
| 9 (en partie) | Passerelle WireGuard (CT 115) : le téléphone ouvre les services hors Wi-Fi. Routes Cloudflare réduites à Vaultwarden | 9 et 10 nov. 2026 |

## Ce qui reste ouvert

- La fin de l'accès distant (phase 9) : `ROOT_URL` de Gitea, SMB par WireGuard, `/admin` de Vaultwarden, noms et HTTPS sur le LAN.
- L'exploitation courante et la sécurité (phase 14) : mises à jour, redémarrages, onduleur, durcissement, secrets.
- Les reprises jouées (phase 12), la copie hors domicile (phase 13), l'observabilité (phase 15), la production depuis le code (phase 16) et une application livrée de bout en bout (phase 17).
- Le dépôt public allégé (phase 10) et le site CV (phase 11).
- Le remplacement d'un disque, le retour arrière d'un snapshot sur la production, et la reprise réelle du coffre sur son zvol (voir [restauration.md](../exploitation/restauration.md)).

## Points à réévaluer

Ces lignes semblent en retard sur ce qui a été fait depuis le 5 nov. Le niveau reste à fixer par moi :

| Compétence | Niveau noté | Ce qui a changé |
| --- | --- | --- |
| Alertes (Administration) | 🔲 | ntfy en place le 5 nov., et validé par une vraie alerte |
| VPN de sortie (WireGuard), WireGuard pour l'accès privé distant | 🟡 | Passerelle du téléphone en service le 9 nov. ; passage de Mullvad à Proton, avec port NAT-PMP, le 29 oct. |
| Workflow Actions (Git et forge) | 🟡 | CI des manifestes (kubeconform) en place et testée en échec volontaire le 6 nov. |
| *(absente)* Ansible, infrastructure as code | — | Huit playbooks validés sur des conteneurs d'essai, deuxième passe sans changement (ADR-010). Une ligne mérite d'être ajoutée |
| *(absente)* Kill switch par compte (nftables) | — | Validé sur le CT 104, et revérifié le 11 nov. |

Les définitions (hyperviseur, LXC, ZFS, CIDR…) sont dans le [glossaire](../concepts/glossaire.md).

# Évolution

Ce document est mis à jour à la fin de chaque grande étape du projet. Le niveau d'une compétence peut évoluer ainsi :

🔲 → 🟡 → 🟢 → 🔵

L'objectif n'est pas de tout passer en 🔵, mais d'être autonome (🟢) sur les technologies utilisées dans le homelab.
