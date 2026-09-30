# Argo CD / GitOps

> Comment le cluster applique l'état désiré versionné dans Git.
>
> Décision GitOps : [ADR-006](ADR/ADR-006-Argo-CD.md). Exposition : [ADR-007](ADR/ADR-007-Argo-CD-exposition.md). Principes : [Architecture.md](Architecture.md). Secrets : [ADR-005](ADR/ADR-005-Sealed-Secrets.md). Manifestes : [kubernetes/argocd/](../kubernetes/argocd/).

---

# Objectif

Git contient l'état désiré des applications Kubernetes. Argo CD compare cet état au cluster et le réconcilie.

Les modifications **des workloads** se font dans Git, puis Sync manuel dans l'UI. La **configuration d'Argo CD lui-même** (Ingress, `cmd-params`) est dans Git mais appliquée à la main : [ADR-007](ADR/ADR-007-Argo-CD-exposition.md).

---

# Exposition

UI : `https://argocd.labo.example`. Namespace `argocd`.

Vaultwarden et Argo CD partagent **le même** point d'entrée Traefik `<ip-k3s-01>:80`. Le routage est le **hostname**.

```
                         Internet
                            │
                         HTTPS
                            ▼
                    ┌─────────────────┐
                    │    Cloudflare   │
                    │  Access + TLS   │
                    └────────┬────────┘
                             │
                     Tunnel "homelab"
                             │ HTTP
                             ▼
                    ┌─────────────────┐
                    │ Traefik :80     │
                    │ <ip-k3s-01>    │
                    └────────┬────────┘
                             │
                Host: argocd.labo.example
                             ▼
                    ┌─────────────────┐
                    │    Argo CD      │
                    │  argocd-server  │
                    │    :8080 HTTP   │
                    └─────────────────┘
```

Cloudflare termine le HTTPS. Le Tunnel envoie `http://<ip-k3s-01>:80`. Traefik : entrypoint `web`.

Argo CD : `server.insecure: "true"` (HTTP interne, 8080). IngressRoute :

- HTTP → `argocd-server:80` ;
- gRPC → `argocd-server:80` en `h2c`.

Fichier : `kubernetes/argocd/ingress/argocd-ingressroute.yaml`.

## Authentification

1. **Cloudflare Access** : qui peut atteindre `argocd.labo.example`. [Cloudflare.md](Cloudflare.md).
2. **Argo CD** : comptes et permissions (compte local `admin`). Mot de passe initial changé ; Secret `argocd-initial-admin-secret` **supprimé**. Aucune valeur secrète ici.

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

```
kubernetes/argocd/
├── applications/
│   └── vaultwarden.yaml
├── bootstrap/
│   └── repo-homelab-sealed-secret.yaml
├── config/
│   └── argocd-cmd-params.yaml
├── ingress/
│   └── argocd-ingressroute.yaml
└── root-application.yaml
```

| Répertoire | Responsabilité | Gestion |
|------------|----------------|---------|
| `applications/` | Applications des workloads | `root` (auto-sync) |
| `bootstrap/` | Accès Git (SealedSecret) | manuelle |
| `config/` | Configuration Argo CD (`cmd-params`) | manuelle |
| `ingress/` | Exposition Traefik (`IngressRoute`) | manuelle |
| `root-application.yaml` | Application racine | Argo CD |

## `applications/`

Les `Application` des **workloads**. Exemple : `kubernetes/argocd/applications/vaultwarden.yaml`.

Chaque enfant définit le dépôt, le chemin du workload, le namespace de destination. **Pas** de `syncPolicy.automated` : synchronisation manuelle.

## `bootstrap/`

Ressources pour faire tourner Argo CD au départ. Exemple : `kubernetes/argocd/bootstrap/repo-homelab-sealed-secret.yaml`.

**Pas** surveillé par le Root Application.

## `config/` et `ingress/`

`argocd-cmd-params.yaml` (`server.insecure`) et `IngressRoute` Traefik. Versionnés, `kubectl apply` manuel. [ADR-007](ADR/ADR-007-Argo-CD-exposition.md).

## `root-application.yaml`

Application `root` : path `kubernetes/argocd/applications/`, auto-sync. Elle crée / réconcilie les Applications enfants. Elle **ne** déploie **pas** les workloads, et **ne** gère **pas** `config/` ni `ingress/`.

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

```
Workload :  Git → root → Application enfant → Sync manuel
```

**Modifier la configuration d'Argo CD** (`config/` ou `ingress/`)

```
Git → commit / push → git pull sur k3s-01 → kubectl apply manuel → Argo CD
```

Fichiers typiques : `kubernetes/argocd/config/argocd-cmd-params.yaml`, `kubernetes/argocd/ingress/argocd-ingressroute.yaml`.

Tout est versionné dans Git. **Tout n'est pas** réconcilié par Argo CD.

Le root reste auto-synchronisé. Les workloads restent sous contrôle manuel.

---

# État actuel — 2026-09-30

| Élément | Valeur |
|---------|--------|
| Version | Argo CD v3.5.3 |
| Namespace | `argocd` |
| Hostname | `argocd.labo.example` |
| Cloudflare Access | activé |
| Tunnel | `homelab` → `http://<ip-k3s-01>:80` |
| Traefik | entrypoint `web`, `IngressRoute` |
| Interne | HTTP, `server.insecure=true` |
| `root` | Applications dans `applications/` seulement |
| Config / Ingress Argo CD | Git + `kubectl apply` |
| Compte | `admin` local ; mot de passe initial changé |

Aucun mot de passe, jeton Cloudflare ou blob Sealed Secret dans cette page.
