# ADR-012 — Où héberger un service : LXC ou K3s

## Statut

Accepté le 11 nov. 2026. Il formalise une règle appliquée service par service du 28 oct. au 4 nov. 2026, et jusque-là notée « critère général encore ouvert » dans chaque document.

## Contexte

Le homelab a deux façons d'héberger un service :

- des **conteneurs LXC** sur Proxmox ;
- le **cluster K3s**, dans la VM `k3s-01` ([ADR-004](ADR-004-K3s.md)), déployé en GitOps par Argo CD ([ADR-006](ADR-006-Argo-CD.md)).

Chaque nouveau service a été placé au cas par cas : Jellyfin, qBittorrent, les outils *arr et Navidrome en LXC ; Vaultwarden et Gitea dans K3s ; le runner Gitea dans un LXC à part. Une même règle se dégageait, déjà formulée dans [forge-gitea.md](../exploitation/forge-gitea.md) : « un service sort du cluster quand il doit lire `tank` sans NFS ».

La contrainte de fond est technique : **la VM `k3s-01` ne voit pas les datasets de l'hôte.** Un LXC, lui, les reçoit directement par un montage (*bind mount*).

## Décision

Une question décide de l'hébergement : **de quoi le service a-t-il besoin pour ses données, et quel code exécute-t-il ?**

| Situation | Hébergement | Raison | Exemples |
| --- | --- | --- | --- |
| Le service lit ou écrit un **dataset de fichiers partagé** sur `tank` | **LXC**, avec un montage direct | Dans K3s, il faudrait un partage NFS entre `pve` et `k3s-01` pour des fichiers déjà sur la même machine | Jellyfin, qBittorrent, Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, Navidrome, Samba |
| Le service a **ses propres données**, non partagées | **K3s**, avec un zvol dédié sur `tank` et un Local PV ([ADR-008](ADR-008-Vaultwarden-tank.md)) | Données isolées, déploiement versionné en GitOps, volume qui survit à la VM | Vaultwarden, Gitea |
| Le service **exécute du code qu'on ne maîtrise pas** | **LXC isolé**, sans aucun montage | Il ne doit voir ni le coffre, ni la forge, ni le fichier d'accès au cluster | Runner Gitea (CT 107) |
| Service d'**infrastructure léger**, sans données | **LXC** | Un rôle par conteneur, indépendant du cluster | `cloudflared` (CT 100), WireGuard (CT 115) |
| **Application maison exposée sur Internet** | **K3s, sous conditions** | Le flux Gitea → GitHub → Argo CD est fait pour ça. Mais un conteneur n'isole pas assez à lui seul (voir « Conséquences ») | À venir |

## Raisons

- **Éviter NFS quand il n'apporte rien.** Les fichiers sont déjà sur `pve`. Un partage NFS vers `k3s-01` ajouterait :
  - un serveur à maintenir et à sécuriser ;
  - des identifiants (UID et GID) à faire correspondre de part et d'autre ;
  - un passage par le réseau virtuel pour chaque lecture, y compris le scan de 2,1 Tio de médias.
  
  Pour une base SQLite, NFS est même déconseillé (voir l'[ADR-008](ADR-008-Vaultwarden-tank.md)).
- **Garder K3s là où il apporte quelque chose** : le déploiement versionné, la réconciliation par Argo CD et l'apprentissage de Kubernetes, pour des services dont les données tiennent dans un volume dédié.
- **Protéger le nœud qui porte le coffre.** `k3s-01` héberge Vaultwarden. Ce qui exécute du code non maîtrisé, ou fait de gros traitements (scans, transcodage), reste en dehors.

## Alternatives étudiées

| Option | Pourquoi elle n'est pas retenue |
| --- | --- |
| NFS de `pve` vers `k3s-01`, et tout dans K3s | Un serveur de plus, la correspondance des identifiants, un scan de 2,1 Tio par le réseau virtuel, et SQLite sur NFS. Beaucoup de complexité pour des fichiers déjà sur la même machine |
| Tout en LXC | On perdrait le GitOps et l'apprentissage de Kubernetes, deux objectifs du projet |
| Décider au cas par cas, sans règle | C'était la situation avant cet ADR : chaque document répétait « critère encore ouvert » |

## Conséquences

- **Deux mondes à exploiter** : Argo CD pour K3s, Ansible pour les LXC ([ADR-010](ADR-010-Ansible-LXC.md)). C'est un coût assumé.
- Les services de médias n'ont pas de déploiement GitOps : leur reconstruction passe par Ansible et par les archives de configuration.
- **Les applications maison exposées sur Internet demandent un isolement renforcé.** Un conteneur n'est pas une frontière de sécurité suffisante, pour trois raisons :
  - tous les pods de `k3s-01` partagent le même noyau ;
  - ce nœud porte Vaultwarden et Gitea ;
  - par défaut, Kubernetes laisse les pods communiquer entre eux et avec l'API.
  
  Avant la première application publique, un ADR dédié (ADR-013) devra trancher ces mesures :
  - un nœud ou une VM séparée pour les applications publiques ;
  - des NetworkPolicies qui refusent tout par défaut ;
  - Pod Security Admission au niveau `restricted` ;
  - pas de jeton de compte de service monté ;
  - des conteneurs non root ;
  - l'analyse des images dans la CI.

## Quand revoir cette décision

- Si le cluster passe à **plusieurs nœuds** : un stockage partagé (NFS, CSI) deviendrait de toute façon nécessaire, et son coût serait déjà payé.
- Si un stockage partagé devient indispensable pour une autre raison.
- Si une application publique arrive : l'ADR-013 précisera la ligne correspondante du tableau.
