# ADR-004 — Plateforme : K3s à un nœud

## Statut

Accepté.

## Contexte

Le homelab doit faire tourner des applications (Vaultwarden, puis d'autres) avec les primitives Kubernetes, sans que l'installation et l'exploitation du cluster deviennent le projet principal.

Proxmox et les LXC restent utilisés autour du cluster (par exemple pour `cloudflared`). L'objectif pédagogique est Kubernetes, pas Kubernetes dans un LXC.

## Décision

Utiliser **K3s**, sur une **VM Debian**, en **cluster à un nœud**.

Ce n'est volontairement **pas** une architecture haute disponibilité :

```
1 nœud K3s
    │
    ├── simplicité
    ├── coût minimal
    └── apprentissage de Kubernetes
```

## Raisons

- Une distribution légère, adaptée à un homelab, et assez proche d'un Kubernetes « standard » pour apprendre.
- Beaucoup moins de travail d'installation et d'administration qu'un cluster construit à la main.
- Le nœud est une VM : l'environnement Kubernetes est séparé de l'hyperviseur.

## Alternatives étudiées

| Option | Commentaire |
| --- | --- |
| kubeadm | Montre davantage les composants et les étapes d'un cluster classique. Utile pour apprendre, mais trop de configuration pour l'objectif actuel |
| k0s | Alternative crédible, sans bénéfice concret qui justifie de changer |
| Tout en LXC | Proxmox et LXC restent pour l'infrastructure. Un nœud Kubernetes en LXC aurait mêlé l'apprentissage aux particularités de Kubernetes dans un conteneur |

## Conséquences

- **La perte du nœud est la perte du cluster.** Il n'y a pas de bascule automatique.
- `local-path` est un stockage local au nœud. Vaultwarden n'y est plus : ses données sont sur un zvol de `tank`, exposé par un Local PV (voir l'[ADR-008](ADR-008-Vaultwarden-tank.md)). Pas de pilote CSI ZFS pour l'instant. L'ancien PVC `local-path` est conservé, figé.
- **La résilience repose sur les sauvegardes et la restauration**, pas sur la réplication. Par exemple, la migration de Vaultwarden s'est faite par un nouveau PVC et une restauration, pas par une fausse haute disponibilité. Voir [sauvegardes.md](../exploitation/sauvegardes.md) et [restauration.md](../exploitation/restauration.md).

Notions : [kubernetes.md](../concepts/kubernetes.md). Premier service : [vaultwarden.md](../exploitation/vaultwarden.md).
