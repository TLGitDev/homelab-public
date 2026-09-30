# ADR-007 — Exposition et configuration d'Argo CD

## Statut

Accepté

## Contexte

Argo CD tourne dans le namespace `argocd`. Il doit être joignable hors LAN pour l'administration GitOps, sans ouvrir de port sur la box, et sans se confondre avec Vaultwarden sur le même Traefik.

Le même origin Tunnel `http://<ip-k3s-01>:80` sert plusieurs hostnames. Traefik route selon le `Host`.

## Décision

Exposer Argo CD sur **`argocd.labo.example`** via Cloudflare Tunnel + **Cloudflare Access**, puis Traefik (`IngressRoute`, entrypoint `web`).

Ne **pas** faire gérer la configuration d'Argo CD par l'Application `root` pour le moment.

Les fichiers `kubernetes/argocd/config/` et `kubernetes/argocd/ingress/` restent **versionnés dans Git** et **appliqués à la main** (`kubectl apply`).

`root` continue de ne gérer que `kubernetes/argocd/applications/`.

Détail : [ArgoCD.md](../ArgoCD.md). Tunnel : [Cloudflare.md](../Cloudflare.md). GitOps : [ADR-006](ADR-006-Argo-CD.md).

## Raisons

- Évite une boucle de bootstrap : Argo CD n'a pas à être déjà opérationnel pour appliquer sa propre exposition / ses `cmd-params`.
- Git reste la source de vérité (reconstruction reproductible).
- Access devant l'UI : qui peut arriver jusqu'à Argo CD. Argo CD garde ensuite ses comptes et permissions.
- HTTP interne (`server.insecure: "true"`, port 8080) : le HTTPS public est celui de Cloudflare, comme Vaultwarden. Traefik route HTTP et gRPC (`h2c`) vers `argocd-server:80`.

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| Self-management (Argo CD applique sa propre config via une Application) | Valable plus tard. Aujourd'hui : risque de se bloquer si l'appli casse l'Ingress ou le serveur. |
| Inclure `config/` et `ingress/` dans `root` | Mélangerait bootstrap d'Argo CD et découverte des workloads. |
| TLS dans le cluster jusqu'à `argocd-server` | Possible. Non retenu : origin Tunnel en HTTP, certificat public chez Cloudflare. |
| Pas d'Access (comme Vaultwarden) | Vaultwarden authentifie des clients Bitwarden. L'UI Argo CD est un outil d'admin : Access en plus du login Argo CD. |

## Conséquences

- Deux authentifications : Access, puis compte Argo CD (`admin` local). Mot de passe initial changé ; le Secret `argocd-initial-admin-secret` est **supprimé**. Aucun mot de passe dans Git ni dans cette doc.
- Modifier l'Ingress ou `server.insecure` : commit, `git pull` sur k3s-01, `kubectl apply` — pas un Sync d'Application.
- Un passage au self-management pourra faire l'objet d'un ADR ultérieur.
