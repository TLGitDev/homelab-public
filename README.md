# Homelab

Ce dépôt contient la conception, la réalisation et l'exploitation d'un homelab personnel.

L'objectif n'est pas seulement d'avoir un serveur qui fonctionne. Il s'agit de comprendre chaque couche, de justifier chaque choix, et de produire une documentation utilisable dans un contexte professionnel.

> Comprendre → Faire → Vérifier → Documenter

## En bref

| Couche | Choix |
| --- | --- |
| Matériel | Un serveur : Ryzen 7 5700G, 32 Go de RAM, NVMe de 2 To, deux IronWolf Pro de 8 To en miroir |
| Hyperviseur | Proxmox VE sur ZFS (`rpool` sur le NVMe, `tank` en miroir) |
| Services d'infrastructure | Un service par conteneur LXC, décrits en Ansible |
| Applications | K3s à un nœud, Traefik, Argo CD (GitOps), Sealed Secrets |
| Forge et CI | Gitea et son runner isolé ; GitHub Actions valide les manifestes avec `kubeconform` |
| Accès | Tunnel Cloudflare pour le seul service public (Vaultwarden), WireGuard pour le reste |
| Sauvegardes | Archives quotidiennes, snapshots ZFS, Restic sur disque USB, alerte ntfy, restaurations testées |

## Organisation du dépôt

| Chemin | Contenu |
| --- | --- |
| [`docs/`](docs/README.md) | La documentation : architecture, exploitation, décisions (ADR), concepts, journal |
| [`kubernetes/`](kubernetes/) | Les manifestes déployés par Argo CD : Vaultwarden, Gitea, Argo CD lui-même |
| [`infrastructure/`](infrastructure/) | Les scripts et units systemd de `pve` et `k3s-01`, la configuration Samba, et les playbooks Ansible des LXC |
| [`.github/workflows/`](.github/workflows/) | La validation des manifestes à chaque push |

Les fichiers de `infrastructure/` ne se déploient pas d'eux-mêmes : un fichier dans Git n'est pas un fichier installé. Chaque page d'exploitation indique où le copier. La chaîne de sauvegarde, par exemple, est décrite dans [sauvegardes.md](docs/exploitation/sauvegardes.md).

La racine du dépôt est le projet. `docs/` n'en est que la partie écrite.

## Par où commencer

1. [docs/README.md](docs/README.md) : le plan de la documentation.
2. [architecture.md](docs/vue-ensemble/architecture.md) : l'état actuel et les principes.
3. [Les décisions (ADR)](docs/decisions/README.md) : pourquoi chaque choix a été fait.
4. [Le journal](docs/projet/journal/README.md) : l'historique des séances.

## Dépôt

La branche principale est `master`.
