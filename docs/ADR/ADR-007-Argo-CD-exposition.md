# ADR-007 — Exposition et configuration d'Argo CD

## Statut

Accepté

## Contexte

Argo CD est déployé dans le namespace `argocd` (K3s).

L'accès externe :

```
Internet
    → Cloudflare Access / TLS
    → Tunnel homelab
    → <ip-k3s-01>:80
    → Traefik
    → Argo CD
```

L'**API Kubernetes n'est pas exposée** sur Internet.

Cloudflare termine le HTTPS public. Le Tunnel envoie du HTTP vers Traefik. Argo CD écoute en HTTP interne (`server.insecure: "true"`). Traefik route vers `argocd-server`.

Le même `:80` sert Vaultwarden et Argo CD ; le `Host` les sépare.

## Décision

### Exposition

Hostname **`argocd.labo.example`**, protégé par **Cloudflare Access**.

IngressRoute Traefik, entrypoint `web` :

- HTTP classique → `argocd-server:80` ;
- gRPC (CLI / API) → `argocd-server:80` en `h2c`.

### Authentification

1. Cloudflare Access : qui atteint le hostname depuis Internet.
2. Argo CD : comptes et RBAC.

Access **ne remplace pas** l'auth Argo CD.

### Gestion de la configuration

Versionné dans Git, **pas** géré par `root` (évite une boucle de bootstrap) :

| Chemin | Rôle | Gestion |
|--------|------|---------|
| `kubernetes/argocd/applications/` | Applications workloads | `root` (auto-sync) |
| `kubernetes/argocd/bootstrap/` | Credentials dépôt Git | manuelle |
| `kubernetes/argocd/config/` | `cmd-params` | manuelle |
| `kubernetes/argocd/ingress/` | IngressRoute | manuelle |

Actuellement : `root` → `vaultwarden`. Enfants : Sync **manuel**.

### Clé Sealed Secrets

Sauvegardée **hors Git** : k3s-01 `~/backups/sealed-secrets/` et copie manuelle `/tank/backups/k3s-01/sealed-secrets/` (`600`). USB via `backup-usb`.

Détail opérationnel : [ArgoCD.md](../ArgoCD.md). Tunnel : [Cloudflare.md](../Cloudflare.md). GitOps : [ADR-006](ADR-006-Argo-CD.md). Secrets : [ADR-005](ADR-005-Sealed-Secrets.md).

## Raisons

- Exposition limitée au hostname nécessaire ; API K8s privée.
- Access + login Argo CD (deux couches).
- Config versionnée, apply manuel : reconstruction possible sans auto-gestion circulaire.
- App of Apps : découverte auto, déploiement des workloads sous contrôle.

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| Self-management (Argo CD applique `config/` / `ingress/`) | Possible plus tard, après un bootstrap / recover clair. Pas maintenant. |
| Inclure `config/` et `ingress/` dans `root` | Mélange bootstrap d'Argo CD et workloads. |
| TLS jusqu'à `argocd-server` | Possible. Origin Tunnel en HTTP ; certificat public chez Cloudflare. |
| Pas d'Access | L'UI est un outil d'admin, contrairement à Vaultwarden. |
| Versionner la clé Sealed Secrets dans Git | Inacceptable. |

## Conséquences

- Mot de passe `admin` changé ; `argocd-initial-admin-secret` supprimé. Aucune valeur secrète dans Git ni ici.
- Modifier Ingress / `server.insecure` : `kubectl apply` après pull, pas un Sync d'Application.
- Perte de k3s-01 **et** de la seule copie de la clé Sealed Secrets = SealedSecrets du dépôt indéchiffrables sur un cluster neuf.
- Self-management : ADR ultérieur, pas au programme actuel.

## Évolution prévue

Faire gérer progressivement sa config par Argo CD **après** avoir formalisé bootstrap et récupération du cluster. Pas de calendrier maintenant.
