# ADR-004 — Distribution Kubernetes (K3s)

## Statut

Accepté

## Contexte

Le homelab doit faire tourner des applications (Vaultwarden, puis d'autres) avec les primitives Kubernetes, sans que l'installation et l'exploitation du cluster deviennent le projet principal.

Proxmox et LXC restent utilisés autour du cluster (ex. `cloudflared`). L'objectif pédagogique est Kubernetes, pas Kubernetes-in-LXC.

## Décision

Utiliser **K3s** sur une **VM Debian**, **cluster à un nœud**.

Ce n'est pas une architecture haute disponibilité.

```
1 nœud K3s
    │
    ├── simplicité
    ├── coût minimal
    └── apprentissage Kubernetes
```

Détail opérationnel : [Kubernetes.md](../Kubernetes.md), [Proxmox.md](../Proxmox.md) (IP), [Vaultwarden.md](../Vaultwarden.md) (premier service).

## Raisons

- Distribution légère, adaptée à un homelab, assez proche d'un Kubernetes « standard » pour l'apprentissage.
- Moins de travail d'installation et d'administration qu'un cluster construit à la main.
- Le nœud est une VM : l'environnement Kubernetes est séparé de l'hyperviseur.

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| kubeadm | Plus exposé aux composants et étapes d'un cluster classique. Utile pédagogiquement, trop de configuration pour l'objectif actuel. |
| k0s | Alternative crédible. Pas de bénéfice concret qui justifiait de changer de distribution. |
| Tout en LXC | Proxmox/LXC reste pour l'infra (Cloudflare). Un nœud K8s en LXC aurait couplé l'apprentissage aux particularités de Kubernetes-in-LXC. |

## Conséquences

- Perte du nœud = perte du cluster. Pas de failover.
- `local-path` = stockage **local au nœud**. Données Vaultwarden **aujourd'hui**. Cible validée (POC) : zvol sur `tank` + Local PV ([ADR-008](ADR-008-Vaultwarden-tank.md)). Pas de CSI ZFS pour l'instant.
- La résilience repose sur **sauvegardes + restauration**, pas sur la réplication du cluster. Exemple : migration Vaultwarden (nouveau PVC + restore), pas une HA fictive. [Sauvegardes.md](../Sauvegardes.md).
