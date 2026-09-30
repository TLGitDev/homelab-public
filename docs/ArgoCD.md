# Argo CD / GitOps

> Comment le cluster applique l'état désiré versionné dans Git.
>
> Décision : [ADR-006](ADR/ADR-006-Argo-CD.md). Principes : [Architecture.md](Architecture.md). Secrets : [ADR-005](ADR/ADR-005-Sealed-Secrets.md). Manifestes : [kubernetes/argocd/](../kubernetes/argocd/).

---

# Objectif

Git contient l'état désiré des applications Kubernetes. Argo CD compare cet état au cluster et le réconcilie.

Les modifications **normales** se font dans Git. Le `kubectl apply` manuel reste exceptionnel : bootstrap, incident, migration, diagnostic.

---

# Flux

```
Modification locale
        │
        ▼
Git commit / push
        │
        ▼
GitHub (dépôt privé)
        │
        ▼
Argo CD
        │
        ▼
Kubernetes
```

```
Bootstrap / migration exceptionnelle
        ↓
état fonctionnel
        ↓
état versionné dans Git
        ↓
Argo CD
        ↓
GitOps normal
```

---

# Rôles

| Élément | Responsabilité |
|---------|----------------|
| Git | Source de vérité (YAML) |
| Argo CD | Observer Git, comparer, appliquer |
| Kubernetes | Exécuter l'état (Pods, Services, …) |
| Sealed Secrets | Déchiffrer les secrets **dans** le cluster |

**Synced** : les ressources du cluster correspondent à Git.

**Healthy** : l'application est considérée saine (Pods up, etc.). Les deux ne sont pas la même chose : on peut être Synced et Unhealthy.

---

# Dépôt privé

Le dépôt GitHub est privé. Argo CD n'utilise **pas** la clé SSH d'administration du serveur.

- Deploy Key GitHub, **lecture seule** ;
- Secret Kubernetes généré par un SealedSecret ;
- label `argocd.argoproj.io/secret-type: repository`.

Fichier : `kubernetes/argocd/bootstrap/repo-homelab-sealed-secret.yaml` → Secret `argocd-repo-homelab` dans le namespace `argocd`.

Aucune clé privée en clair dans Git.

Clone : `git@github.com:TLGitDev/homelab.git`.

---

# Applications

Une ressource `Application` (API Argo CD) décrit **une** appli : quel chemin Git, vers quel namespace.

Les `Application` vivent dans le namespace `argocd`. Les ressources de l'appli vivent dans **leur** namespace (ex. `vaultwarden`).

Patron :

| Champ | Rôle |
|-------|------|
| `repoURL` | Dépôt Git |
| `path` | Dossier de manifestes |
| `targetRevision` | Branche / tag / SHA (`HEAD` = `master`) |
| `destination.namespace` | Namespace cible |

Nouvelle appli : dossier `kubernetes/<app>/` + un fichier dans `kubernetes/argocd/applications/`. Le root la découvre ; le Sync du workload reste manuel.

Première appli : [Vaultwarden.md](Vaultwarden.md).

---

# Organisation des manifests

Trois catégories, volontairement séparées.

```
kubernetes/argocd/
├── applications/
│   └── vaultwarden.yaml
├── bootstrap/
│   └── repo-homelab-sealed-secret.yaml
└── root-application.yaml
```

## `applications/`

Les `Application` des **workloads**. Exemple : `kubernetes/argocd/applications/vaultwarden.yaml`.

Chaque enfant définit le dépôt, le chemin du workload, le namespace de destination. **Pas** de `syncPolicy.automated` : synchronisation manuelle.

## `bootstrap/`

Ressources pour faire tourner Argo CD au départ. Exemple : `kubernetes/argocd/bootstrap/repo-homelab-sealed-secret.yaml`.

**Pas** surveillé par le Root Application.

## `root-application.yaml`

Application `root` : path `kubernetes/argocd/applications/`, auto-sync. Elle crée / réconcilie les Applications enfants. Elle **ne** déploie **pas** les workloads.

---

# Workflow

**Ajouter une application**

1. Manifestes du workload dans `kubernetes/<application>/`.
2. `Application` dans `kubernetes/argocd/applications/`.
3. Commit et push.
4. Le Root Application découvre la nouvelle Application.
5. Vérifier l'état dans Argo CD.
6. `Sync` **manuel** sur l'enfant.

**Modifier un workload existant**

1. Modifier `kubernetes/<application>/`.
2. Commit et push.
3. Argo CD passe l'Application en `OutOfSync`.
4. `Sync` manuel.

Le root reste auto-synchronisé. Les workloads restent sous contrôle manuel.
