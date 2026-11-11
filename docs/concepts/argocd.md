# Argo CD — GitOps

Argo CD applique au cluster K3s l'état décrit dans Git, et signale tout écart. Les applications se déploient en deux temps : Argo CD découvre automatiquement chaque nouvelle application, mais son déploiement attend une synchronisation manuelle. L'interface se joint depuis le LAN ou par WireGuard, sur `http://<ip-k3s-01>/`.

Décisions : GitOps ([ADR-006](../decisions/ADR-006-Argo-CD.md)), exposition et configuration ([ADR-007](../decisions/ADR-007-Argo-CD-exposition.md)), secrets ([ADR-005](../decisions/ADR-005-Sealed-Secrets.md)). Manifestes : `kubernetes/argocd/`.

## 1. Principe

```
Modification locale
        │
        ▼
git commit / git push
        │
        ▼
GitHub (dépôt privé)
        │
        ▼
Argo CD  ── compare Git et le cluster
        │
        ▼
Kubernetes
```

| Élément | Responsabilité |
| --- | --- |
| Git | Source de vérité : les fichiers YAML |
| Argo CD | Observer Git, comparer avec le cluster, appliquer |
| Kubernetes | Exécuter l'état décrit (pods, services…) |
| Sealed Secrets | Déchiffrer les secrets **dans** le cluster |

Deux états à ne pas confondre :

- **`Synced`** : les ressources du cluster correspondent à Git.
- **`Healthy`** : l'application fonctionne (pods démarrés, etc.).

On peut être `Synced` et pas `Healthy` : Git a bien été appliqué, mais l'application ne démarre pas.

**Piège déjà rencontré.** Un SealedSecret synchronisé met bien à jour le Secret. Mais si l'application lit ce Secret en variable d'environnement, le pod déjà lancé garde l'ancienne valeur jusqu'à un `rollout restart`. C'est arrivé avec Vaultwarden le 17 oct. 2026 (voir [vaultwarden.md](../exploitation/vaultwarden.md), section 9).

### Le démarrage, une exception

Un service peut d'abord être installé à la main (démarrage du cluster, migration exceptionnelle), puis repris en GitOps :

```
Démarrage ou migration exceptionnelle
        ↓
état fonctionnel
        ↓
état versionné dans Git
        ↓
Argo CD
        ↓
GitOps normal
```

## 2. Accès

| Élément | Valeur |
| --- | --- |
| Adresse | `http://<ip-k3s-01>/`, depuis le LAN ou par WireGuard |
| Route publique | `argocd.labo.example`, **désactivée le 10 nov. 2026** |
| Namespace | `argocd` |
| Version | v3.5.3 (relevée le 1er oct. 2026) |
| Compte | `admin` local. Mot de passe initial changé, Secret `argocd-initial-admin-secret` supprimé |
| API Kubernetes | **Non** exposée sur Internet |

Le chemin d'une requête :

```
Navigateur (LAN ou WireGuard)
        │ HTTP
        ▼
Traefik, point d'entrée « web » (<ip-k3s-01>:80)
        │  règle Host(<ip-k3s-01>) ou Host(argocd.labo.example)
        ▼
argocd-server (HTTP interne)
```

Argo CD écoute en HTTP interne (`server.insecure: "true"`). L'IngressRoute `kubernetes/argocd/ingress/argocd-ingressroute.yaml` a trois règles :

| Règle | Destination |
| --- | --- |
| `Host(argocd.labo.example)` avec `Content-Type: application/grpc` | `argocd-server:80` en `h2c` (CLI et API gRPC) |
| `Host(argocd.labo.example)` | `argocd-server:80` |
| `Host(<ip-k3s-01>)` | `argocd-server:80`. C'est l'accès LAN actuel |

Vaultwarden partage le même Traefik : c'est le nom ou l'adresse demandés qui départagent les deux. Sur le LAN, Argo CD répond en HTTP sur le port 80, et Vaultwarden en HTTPS sur le port 443.

Quand la route publique était active, Cloudflare Access protégeait l'accès, puis Argo CD demandait sa propre connexion. Access ne remplace pas la connexion à Argo CD (voir l'[ADR-007](../decisions/ADR-007-Argo-CD-exposition.md)).

## 3. L'accès au dépôt privé

Le dépôt GitHub est privé. Argo CD n'utilise **pas** la clé SSH d'administration du serveur, mais une **clé de déploiement** GitHub (*Deploy Key*) en lecture seule :

- elle est stockée dans un Secret Kubernetes issu d'un SealedSecret : `kubernetes/argocd/bootstrap/repo-homelab-sealed-secret.yaml` → Secret `argocd-repo-homelab`, namespace `argocd` ;
- ce Secret porte le label `argocd.argoproj.io/secret-type: repository` ;
- le dépôt est cloné depuis `git@github.com:TLGitDev/homelab.git`.

Aucune clé privée en clair dans Git.

## 4. Organisation des manifestes

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

| Élément | Rôle | Appliqué par |
| --- | --- | --- |
| `root-application.yaml` | Application racine : surveille `applications/`, en synchronisation automatique | Argo CD |
| `applications/` | Une application Argo CD par service | `root`, automatiquement |
| `bootstrap/` | Accès au dépôt Git (SealedSecret) | `kubectl apply`, à la main |
| `config/` | Paramètres d'Argo CD (`server.insecure`) | `kubectl apply`, à la main |
| `ingress/` | IngressRoute Traefik | `kubectl apply`, à la main |

`root` ne déploie aucun service lui-même. Il ne gère pas non plus `bootstrap/`, `config/` ni `ingress/` : sinon, Argo CD gérerait sa propre installation, ce qui crée une boucle (voir l'[ADR-007](../decisions/ADR-007-Argo-CD-exposition.md)). Tout est versionné dans Git, mais **tout n'est pas** appliqué par Argo CD.

### Une application Argo CD

Une ressource `Application` décrit **un** service : quel dossier du dépôt, vers quel namespace. Elle vit dans le namespace `argocd`, alors que les ressources du service vivent dans leur propre namespace.

| Champ | Rôle |
| --- | --- |
| `repoURL` | Dépôt Git |
| `path` | Dossier des manifestes (par exemple `kubernetes/vaultwarden`) |
| `targetRevision` | Branche, tag ou commit. `HEAD` suit `master` |
| `destination.namespace` | Namespace cible |

Les applications enfants n'ont **pas** de `syncPolicy.automated` : leur déploiement est toujours manuel.

| Application | Dossier | Namespace |
| --- | --- | --- |
| `vaultwarden` | `kubernetes/vaultwarden` | `vaultwarden` |
| `gitea` | `kubernetes/gitea` | `gitea` |

## 5. Le contrôle des manifestes en CI

À chaque push et sur chaque demande de fusion, GitHub Actions vérifie `kubernetes/` avec `kubeconform` v0.8.0, en mode strict, contre le schéma de Kubernetes 1.36.4 (la version de `k3s-01` relevée le 6 nov.). Le workflow est `.github/workflows/manifestes.yml`. Le binaire est téléchargé puis vérifié par son empreinte SHA-256. Ce contrôle ne déploie rien et ne parle pas à Argo CD.

Ses limites :

- `Application`, `SealedSecret` et `IngressRoute` ne sont pas dans le schéma standard : ils sont ignorés ;
- une image absente, un mauvais nom de Service, un secret en clair ou un conteneur privilégié passent sans erreur, puisque le schéma les autorise.

**Validation du 6 nov. 2026** :
1. Première exécution verte en 11 s (commit `0a70da8`).
2. Échec volontaire : le commit `66f4880` ajoute `kubernetes/controle-schema/configmap.yaml`, un ConfigMap `controle-schema-invalide` avec un champ `spec` interdit. Le contrôle échoue en 10 s, code de sortie 1.
3. Fichier retiré (commit `193e6cd`), exécution suivante verte en 8 s.

Le dossier `controle-schema` n'était suivi par aucune application Argo CD.

## 6. Procédures

### 6.1 Ajouter une application

**Prérequis**

- Le service respecte la règle d'hébergement : ses données tiennent dans un volume dédié ([ADR-012](../decisions/ADR-012-LXC-ou-K3s.md)).
- Ses secrets sont des SealedSecrets.

**Action**

1. Écrire les manifestes du service dans `kubernetes/<application>/`.
2. Ajouter une `Application` dans `kubernetes/argocd/applications/`.
3. Commiter et pousser.
4. Attendre que la CI soit verte.
5. Dans Argo CD, vérifier que `root` a découvert la nouvelle application.
6. Lancer un **Sync** manuel de cette application.

**Vérification**

- L'application est `Synced` et `Healthy`, et le service répond.

### 6.2 Modifier un service existant

**Prérequis**

- La modification est commitée et poussée, et **la CI est verte**.

**Action**

1. Dans Argo CD, l'application passe en `OutOfSync` : regarder l'écart (*diff*).
2. Lancer le **Sync** manuel.

**Vérification**

- L'application revient en `Synced` et `Healthy`.
- Si la modification touche un Secret lu en variable d'environnement, lancer aussi `kubectl -n <namespace> rollout restart deployment/<nom>`.

**Si la CI est rouge**, ne pas cliquer sur **Sync**. Le commit est déjà sur `master` : Argo CD l'appliquerait quand même. Corriger d'abord par un nouveau commit.

### 6.3 Modifier la configuration d'Argo CD

Concerne `config/` et `ingress/`.

**Prérequis**

- La modification est commitée et poussée.

**Action**

```
git pull           # sur k3s-01, dans le clone du dépôt
kubectl apply -f kubernetes/argocd/config/argocd-cmd-params.yaml
kubectl apply -f kubernetes/argocd/ingress/argocd-ingressroute.yaml
```

Il n'y a pas de Sync à lancer : ces fichiers ne sont pas gérés par une application.

**Vérification**

- L'interface répond toujours sur `http://<ip-k3s-01>/`.

## 7. Clé Sealed Secrets

La clé du controller Sealed Secrets est **hors de Git** : sur `k3s-01` dans `~/backups/sealed-secrets/`, avec une copie manuelle dans `/tank/backups/k3s-01/sealed-secrets/` (mode `600`), puis sur le disque USB par `backup-usb`. Sans elle, un cluster neuf ne peut pas déchiffrer les SealedSecrets du dépôt (voir [restauration.md](../exploitation/restauration.md), scénario 5).

Aucun mot de passe, jeton ou texte chiffré ne figure dans cette page.
