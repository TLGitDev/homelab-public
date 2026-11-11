# ADR-007 — Exposition et configuration d'Argo CD

## Statut

Accepté. **Révisé le 10 nov. 2026** : la route publique d'Argo CD est désactivée (voir « Révisions »).

## Contexte

Argo CD est déployé dans le namespace `argocd`, sur K3s. Il faut décider comment y accéder, et comment gérer sa propre configuration sans créer de boucle.

Le chemin d'accès externe prévu :

```
Internet
    → Cloudflare Access / TLS
    → Tunnel homelab
    → <ip-k3s-01>:80
    → Traefik
    → Argo CD
```

L'**API Kubernetes n'est pas exposée** sur Internet.

Cloudflare termine le HTTPS public, et le tunnel transmet du HTTP à Traefik. Argo CD écoute donc en HTTP interne (`server.insecure: "true"`), et Traefik route vers `argocd-server`. Le même port 80 sert Vaultwarden et Argo CD : c'est l'en-tête `Host` qui les distingue.

## Décision

### Exposition

- Nom public **`argocd.labo.example`**, protégé par **Cloudflare Access**.
- Une IngressRoute Traefik, sur le point d'entrée `web` :
  - le HTTP classique va vers `argocd-server:80` ;
  - le gRPC (CLI et API) va vers `argocd-server:80`, en `h2c`.

### Authentification

1. Cloudflare Access décide qui peut atteindre le nom depuis Internet.
2. Argo CD gère ensuite ses comptes et ses droits (RBAC).

Access **ne remplace pas** l'authentification d'Argo CD.

### Gestion de la configuration

Tout est versionné dans Git, mais la configuration d'Argo CD n'est **pas** gérée par l'application racine. Cela évite une boucle : Argo CD qui gère sa propre installation.

| Chemin | Rôle | Gestion |
| --- | --- | --- |
| `kubernetes/argocd/applications/` | Applications des services | `root`, synchronisation automatique |
| `kubernetes/argocd/bootstrap/` | Accès au dépôt Git | Manuelle |
| `kubernetes/argocd/config/` | Paramètres (`cmd-params`) | Manuelle |
| `kubernetes/argocd/ingress/` | IngressRoute | Manuelle |

### Clé Sealed Secrets

Sauvegardée **hors de Git** : sur `k3s-01` dans `~/backups/sealed-secrets/`, avec une copie manuelle dans `/tank/backups/k3s-01/sealed-secrets/` (mode `600`), puis sur le disque USB par `backup-usb`.

## Raisons

- On n'expose que le nom nécessaire, et l'API Kubernetes reste privée.
- Deux couches d'authentification : Access, puis Argo CD.
- La configuration versionnée et appliquée à la main permet de reconstruire Argo CD sans dépendre de lui-même.
- Le modèle App of Apps découvre les applications automatiquement, tout en gardant leur déploiement sous contrôle.

## Alternatives étudiées

| Option | Commentaire |
| --- | --- |
| Argo CD gère sa propre configuration (`config/`, `ingress/`) | Possible plus tard, une fois le démarrage et la reprise du cluster bien formalisés. Pas maintenant |
| Inclure `config/` et `ingress/` dans `root` | Mélange l'installation d'Argo CD et les services |
| TLS jusqu'à `argocd-server` | Possible, mais l'origine du tunnel est en HTTP et le certificat public est chez Cloudflare |
| Pas d'Access | Écarté : l'interface est un outil d'administration, contrairement à Vaultwarden |
| Versionner la clé Sealed Secrets dans Git | Inacceptable |

## Conséquences

- Le mot de passe `admin` a été changé, et `argocd-initial-admin-secret` supprimé. Aucune valeur secrète dans Git ni dans cette doc.
- Modifier l'IngressRoute ou `server.insecure` demande un `kubectl apply` après un `git pull`, et non une synchronisation d'application.
- Perdre `k3s-01` **et** la seule copie de la clé Sealed Secrets rendrait indéchiffrables, sur un cluster neuf, tous les SealedSecrets du dépôt.
- Faire gérer à Argo CD sa propre configuration fera l'objet d'un ADR ultérieur. Ce n'est pas au programme.

## Évolution prévue

Faire gérer progressivement sa configuration par Argo CD, **après** avoir formalisé le démarrage et la reprise du cluster. Pas de calendrier pour l'instant.

## Révisions

**10 nov. 2026 — Plus de route publique.** La route `argocd.labo.example` est désactivée dans le tunnel. Argo CD se joint par Traefik depuis le LAN, ou depuis le téléphone par WireGuard (voir l'[ADR-003](ADR-003-Cloudflare-Tunnel.md)). Cloudflare Access n'est donc plus devant Argo CD ; l'authentification d'Argo CD reste. La règle de cet ADR (Access obligatoire devant un outil d'administration publié) s'appliquerait si la route était rouverte.

Exploitation : [argocd.md](../concepts/argocd.md). Tunnel : [cloudflare.md](../exploitation/cloudflare.md). Voir aussi l'[ADR-005](ADR-005-Sealed-Secrets.md) et l'[ADR-006](ADR-006-Argo-CD.md).
