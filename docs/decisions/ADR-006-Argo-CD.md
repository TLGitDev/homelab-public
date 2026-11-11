# ADR-006 — GitOps : Argo CD

## Statut

Accepté. Complété le 4 nov. 2026 par la décision sur la forge (voir « Révisions »).

## Contexte

Les manifestes Kubernetes sont versionnés dans Git. Il faut un moyen de les appliquer au cluster, et surtout de **savoir** si l'état réel du cluster correspond encore à Git.

L'objectif pédagogique est de bien distinguer « c'est dans Git » de « le cluster est conforme ».

## Décision

Utiliser **Argo CD** pour réconcilier en continu l'état désiré (Git) et l'état réel (Kubernetes).

```
GitHub
   │
   ▼
Argo CD
   │
   ▼
Kubernetes
```

Git décrit l'état désiré. Argo CD compare en permanence et signale toute dérive. Par exemple, `replicas: 1` dans Git et `2` dans le cluster donnent `OutOfSync`.

### Le modèle App of Apps

Une application racine, `root`, sert à **découvrir** les applications ; chaque application enfant **déploie** un service.

```
kubernetes/argocd/
├── applications/
│   ├── gitea.yaml
│   └── vaultwarden.yaml
├── bootstrap/
│   └── repo-homelab-sealed-secret.yaml
├── config/
│   └── argocd-cmd-params.yaml
├── ingress/
│   └── argocd-ingressroute.yaml
└── root-application.yaml
```

- `root` surveille **uniquement** `kubernetes/argocd/applications/`, et se synchronise automatiquement (`syncPolicy: automated: {}`).
- Les applications enfants n'ont **pas** de synchronisation automatique. Une nouvelle entrée dans `applications/` apparaît toute seule dans Argo CD, mais son déploiement attend un **Sync manuel**.
- `bootstrap/` (clé de déploiement), `config/` et `ingress/` restent hors de `root` (voir l'[ADR-007](ADR-007-Argo-CD-exposition.md)).

```
Git
 │
 ▼
Application racine (synchronisation automatique)
 │
 ├── Application/vaultwarden   → synchronisation manuelle
 └── Application/gitea         → synchronisation manuelle
```

## Raisons

- Une réconciliation continue, et pas seulement un `apply` ponctuel.
- De la visibilité : état de chaque application (`Synced` / `OutOfSync`, `Healthy` / `Degraded`) et ressources associées. C'est utile pour apprendre, et pour suivre une migration (par exemple Vaultwarden `Synced` / `Healthy`).

## Alternatives étudiées

| Option | Commentaire |
| --- | --- |
| Flux | GitOps tout à fait adapté. Argo CD a été préféré pour son interface d'observation, pas parce que Flux serait inadapté |
| GitHub Actions + `kubectl apply` | Déploie après un commit, mais c'est une **suite d'actions**, pas un contrôleur qui maintient l'état. Un workflow terminé ne détecte pas une dérive ultérieure |

```
CI      : commit → workflow → kubectl apply → terminé
Argo CD : Git ⟷ cluster, en continu
```

## Conséquences

- Les changements normaux passent par Git. Un `kubectl` manuel est réservé au démarrage du cluster, aux incidents, aux migrations et au diagnostic.
- Le dépôt privé est lu par une clé de déploiement en lecture seule, distincte de la clé d'administration du serveur.
- `targetRevision: HEAD` suit la branche `master`.
- `root` se synchronise automatiquement ; les services, à la main.

## Révisions

**4 nov. 2026 — Argo CD continue de lire GitHub.** Avec l'arrivée de la forge Gitea ([ADR-011](ADR-011-Gitea.md)), Argo CD aurait pu lire Gitea. Il lit toujours GitHub. Le dépôt `homelab` reste sur GitHub seul. Les nouvelles applications se poussent sur Gitea, un miroir les recopie vers GitHub, et Argo CD déploie cette copie. La forge ne devient ainsi jamais la seule copie de sa propre définition. Voir [forge-gitea.md](../exploitation/forge-gitea.md).

Notions et exploitation : [argocd.md](../concepts/argocd.md).
