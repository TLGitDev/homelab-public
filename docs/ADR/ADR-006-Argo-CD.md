# ADR-006 — GitOps (Argo CD)

## Statut

Accepté

## Contexte

Les manifestes Kubernetes sont versionnés dans Git. Il faut un moyen de les appliquer au cluster et de **savoir** si l'état réel correspond encore à Git.

Objectif pédagogique : distinguer « c'est dans Git » et « le cluster est conforme ».

## Décision

Utiliser **Argo CD** pour la réconciliation continue entre l'état désiré (Git) et l'état réel (Kubernetes).

```
GitHub
   │
   ▼
Argo CD
   │
   ▼
Kubernetes
```

Git = état désiré. Argo CD compare en permanence et signale le drift (ex. `replicas: 1` dans Git, `2` dans le cluster → OutOfSync).

Détail : [ArgoCD.md](../ArgoCD.md). Première Application : [Vaultwarden.md](../Vaultwarden.md).

## Raisons

- Réconciliation, pas seulement un `apply` ponctuel.
- Visibilité : Application, Synced / OutOfSync, Healthy / Degraded, ressources associées. Utile pour apprendre et pour une migration (ex. Vaultwarden Synced / Healthy).

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| Flux | GitOps tout à fait adapté. Non retenu pour l'instant : Argo CD a été choisi pour l'interface d'observation, pas parce que Flux serait inadapté. |
| GitHub Actions + `kubectl apply` | Déploie après un commit. C'est une **séquence d'actions**, pas un contrôleur qui maintient l'état. Un workflow « terminé » ne détecte pas un drift ultérieur. |

```
CI :     commit → workflow → kubectl apply → terminé
Argo CD : Git ⟷ cluster, en continu
```

## Conséquences

- Les changements normaux passent par Git. `kubectl` manuel = bootstrap, incident, migration, diagnostic.
- Le dépôt privé est lu par une Deploy Key (lecture seule), distincte de la clé d'admin du serveur.
- `targetRevision: HEAD` suit `master`.
