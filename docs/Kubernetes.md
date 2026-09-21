# Kubernetes

> Cours : pourquoi Kubernetes, modèle déclaratif, ressources.
>
> Pas encore déployé sur le homelab. Feuille de route : [Architecture.md](Architecture.md).
> Définitions courtes : [Glossaire.md](Glossaire.md).

---

# Pourquoi Kubernetes ?

## Installation directe sur Linux

```
Linux
├── Nginx
├── PostgreSQL
├── Vaultwarden
└── Paperless
```

Inconvénients : dépendances partagées, conflits de versions, mises à jour risquées, faible isolation.

## Docker

```
Linux
└── Docker
    ├── Vaultwarden
    ├── PostgreSQL
    └── Paperless
```

Docker apporte : isolation, portabilité, reproductibilité, indépendance des dépendances.

Limite : Docker ne gère pas un grand nombre de conteneurs répartis sur plusieurs machines.

## Kubernetes

Kubernetes ne remplace pas Docker. Il **orchestre** des conteneurs pour maintenir automatiquement l'état souhaité du système.

---

# Philosophie

Kubernetes est un système **déclaratif**.

L'administrateur décrit l'état souhaité du cluster, pas les étapes pour y parvenir.

Exemple : une application Vaultwarden, une réplique, une image précise, un volume persistant.

Kubernetes est ensuite chargé d'obtenir puis de maintenir cet état.

À retenir : Kubernetes n'exécute pas des commandes. Il maintient un état.

---

# État désiré vs état réel

Deux états coexistent en permanence.

**État désiré** — enregistré dans l'API Server.

```
Deployment
replicas = 3
```

**État réel** — observé dans le cluster.

```
2 Pods en fonctionnement
```

Les contrôleurs comparent continuellement ces deux états. Toute différence est corrigée automatiquement.

---

# Réconciliation

Principe fondamental.

1. Lire l'état désiré.
2. Observer l'état réel.
3. Calculer les différences.
4. Corriger uniquement les différences.
5. Recommencer.

Les contrôleurs ne rejouent pas les événements. Ils reconstruisent toujours leur décision à partir de l'état **courant**.

---

# API Server

Source de vérité du cluster. Toutes les ressources y sont enregistrées : Pods, Deployments, Services, ConfigMaps, Secrets.

Les fichiers YAML servent uniquement à **modifier** cette source de vérité. Une fois appliqué, le YAML n'est plus utilisé par Kubernetes.

---

# Anatomie d'un manifeste

Toutes les ressources suivent la même structure.

```yaml
apiVersion: ...
kind: ...
metadata:
  ...
spec:
  ...
```

| Champ | Rôle |
|-------|------|
| `apiVersion` | Version de l'API pour interpréter la ressource (rétrocompatibilité). |
| `kind` | Type : Deployment, Service, Pod, PersistentVolumeClaim, Secret… |
| `metadata` | Identité : `name`, `namespace`, `labels`, `annotations`, `ownerReferences`, UID. N'influence pas directement le comportement. |
| `spec` | État désiré. Différent selon le `kind` (réplicas et template pour un Deployment, ports et selectors pour un Service, capacité et StorageClass pour un PVC). |

## Template du Pod

`spec.template` **n'est pas un Pod**. C'est le modèle de fabrication d'un futur Pod. Le ReplicaSet s'en sert pour créer les Pods.

Le template reprend la structure d'un Pod :

```yaml
template:
  metadata:
    labels:
      ...
  spec:
    containers:
      ...
```

## Containers

`containers` est une **liste**. Un Pod peut en contenir plusieurs : même IP, mêmes volumes, même cycle de vie — une seule unité de déploiement.

## containerPort

`containerPort` **n'ouvre pas le port**. Il décrit le port sur lequel l'application écoute. Utilisé par les Services, les probes, l'observabilité. Le conteneur fonctionnerait sans ce champ : c'est une description, pas une config réseau.

Les ports peuvent être **nommés** pour réduire le couplage :

```yaml
ports:
  - name: http
    containerPort: 80
```

Un Service peut alors utiliser `targetPort: http` au lieu de `80`. Le numéro peut changer sans modifier les Services.

---

# Contrôleurs

Ensemble de contrôleurs indépendants, chacun une responsabilité : Deployment, ReplicaSet, Service, Job, StatefulSet, etc.

Chacun observe les ressources qui le concernent, puis réconcilie.

## Watches et work queues

Les contrôleurs sont informés des changements par des *watches*.

Un événement n'est **pas** la source de vérité. Il signifie seulement : « une ressource a probablement changé ».

Chaque contrôleur a sa file de travail. Le traitement relit toujours l'état actuel depuis l'API Server avant de décider.

Kubernetes est **orienté état** (state-driven), pas orienté événements (event-driven).

---

# Ressources

Kubernetes n'est pas une application monolithique. Il est composé de ressources spécialisées. Chacune a une **responsabilité unique** et délègue le reste. Cette séparation est un principe fondamental.

Le développeur décrit ce qu'il souhaite. Les contrôleurs maintiennent cet état :

```
État désiré
        │
        ▼
Une ressource décrit un besoin
        │
        ▼
Un Controller réconcilie
        │
        ▼
État réel
```

| Ressource | Responsabilité |
|-----------|----------------|
| Pod | Exécuter les conteneurs |
| ReplicaSet | Garantir N Pods identiques |
| Deployment | Gérer le cycle de vie de l'application |
| Service | Identité réseau stable |
| EndpointSlice | Liste des Pods actuellement joignables |
| Ingress | Exposer les Services vers l'extérieur |
| PersistentVolumeClaim | Exprimer un besoin de stockage |
| StorageClass | Politique de création des volumes |
| PersistentVolume | Représenter un volume réellement disponible |
| Secret | Stocker des informations sensibles |
| ConfigMap | Stocker la configuration non sensible |

## Pod

**Rôle** — plus petite unité de déploiement. Exécute un ou plusieurs conteneurs qui partagent la même IP, le même réseau, les mêmes volumes.

**Responsable de :**

- lancer les conteneurs ;
- leur fournir un environnement d'exécution (dont une IP) ;
- partager le réseau et les volumes entre les conteneurs du Pod.

**Ne fait pas :**

- ne se recrée pas automatiquement ;
- ne gère pas les mises à jour ;
- ne doit pas être manipulé directement.

Un Pod est **jetable**. Lorsqu'il est supprimé, il est considéré comme perdu.

Règle : un Pod = une responsabilité. Deux applications au cycle de vie indépendant → deux Pods (Vaultwarden et PostgreSQL séparés). Un sidecar (logs, proxy, sync) partage le Pod de l'application principale.

## ReplicaSet

**Rôle** — garantir qu'il existe toujours N Pods identiques.

Il ne connaît qu'une chose : *je dois maintenir exactement N Pods.*

**Responsable de :**

- créer les Pods ;
- recréer les Pods supprimés ;
- supprimer les Pods en trop.

**Ne fait pas :**

- ne gère pas les mises à jour applicatives ;
- ne décide pas du nombre de Pods souhaité (c'est le Deployment).

## Deployment

**Rôle** — gérer le cycle de vie d'une application.

**Responsable de :**

- créer les ReplicaSets ;
- effectuer les rolling updates ;
- effectuer les rollbacks ;
- modifier le nombre de réplicas souhaité.

**Ne fait pas :**

- ne crée jamais directement les Pods.

Le Deployment délègue entièrement la gestion des Pods au ReplicaSet.

```
Deployment
        │
        │  définit l'état désiré
        ▼
ReplicaSet
        │
        │  garantit qu'il existe toujours N Pods
        ▼
Pod
        │
        │  exécute les conteneurs
        ▼
Container(s)
```

## Service

**Problème** — les Pods sont éphémères. Recréé, un Pod change de nom et d'IP. On ne peut pas communiquer directement avec lui.

**Solution** — le Service fournit une identité réseau stable (ClusterIP, constante). Les applications parlent au Service, jamais aux Pods. Les Pods peuvent être recréés sans impact sur les clients.

**Responsable de :**

- fournir une adresse IP stable ;
- exposer un point d'entrée unique ;
- répartir les requêtes entre plusieurs Pods.

**Ne fait pas :**

- ne lance pas de Pods ;
- ne surveille pas les Pods ;
- ne connaît pas directement leurs adresses IP.

Le Service ne connaît pas les Pods. Il connaît uniquement les **labels** qu'il recherche.

## Labels

Paires clé/valeur attachées aux ressources. Langage commun de Kubernetes : on retrouve des objets **sans connaître leur nom**.

```yaml
labels:
  app: nginx
  environment: production
  tier: frontend
```

Utilisés notamment par : Services, ReplicaSets, Deployments, Scheduler, Network Policies, Prometheus, ArgoCD.

## Selector

Un selector sélectionne les ressources qui portent certains labels.

```yaml
selector:
  app: nginx
```

## EndpointSlice

Le Service ne maintient pas lui-même la liste des Pods. Cette responsabilité appartient au **EndpointSlice Controller**.

Lorsqu'un Pod apparaît ou disparaît : le contrôleur met à jour les EndpointSlices. Le Service continue de fonctionner sans modification.

---

# Cycle de vie d'une requête

Le client ne parle jamais au Pod. Il passe par le DNS du cluster, puis le Service, puis la liste à jour des Pods.

```
Application cliente
        │
        ▼
DNS Kubernetes
nginx.default.svc.cluster.local
        │
        ▼
Service
IP virtuelle (10.43.x.x)
        │
        ▼
EndpointSlice
Liste des Pods disponibles
        │
        ▼
Pod
10.42.x.x
```

`10.43.x.x` et `10.42.x.x` sont des plages typiques (ex. K3s : ClusterIP vs Pod). Ce ne sont pas les IP du LAN homelab.

## Mise à jour des endpoints

Le Service ne modifie **jamais** directement la liste des Pods. C'est l'EndpointSlice Controller.

```
Pod supprimé
        ↓
ReplicaSet
        ↓
Nouveau Pod
        ↓
EndpointSlice Controller
        ↓
Mise à jour des EndpointSlices
        ↓
Le Service continue de fonctionner
```

---

# Hiérarchie (réseau inclus)

```
Deployment
        │
        │  crée
        ▼
ReplicaSet
        │
        │  garantit le nombre de Pods
        ▼
Pod
        │
        │  possède des labels
        ▼
Service
        │
        │  sélectionne les Pods via les labels
        ▼
EndpointSlice
        │
        ▼
Liste des Pods actuellement disponibles
```

La propriété Deployment → ReplicaSet → Pod est dans `metadata.ownerReferences`. Les noms (`nginx` → `nginx-7b9867795` → `nginx-7b9867795-vkmtr`) ne sont qu'une convention. Détail : section suivante.

---

# Qui réagit à quoi ?

Les événements ne sont pas la source de vérité. Ils indiquent qu'une ressource a probablement changé. Chaque contrôleur relit ensuite l'état depuis l'API Server.

| Événement | Responsable |
|-----------|-------------|
| Un Pod est supprimé | ReplicaSet |
| Le nombre de Pods désiré change | Deployment |
| Une nouvelle version de l'image est déployée | Deployment |
| Un Pod correspondant apparaît | EndpointSlice Controller |
| Un Pod correspondant disparaît | EndpointSlice Controller |
| Un client appelle un Service | Service + EndpointSlice |
| Un Node tombe | Scheduler + contrôleurs (selon le contexte) |
| Un Pod devient indisponible sans disparaître | kubelet (selon la nature du problème) |

---

# Qui est propriétaire de qui ?

Kubernetes ne se base **jamais** sur les noms pour relier les objets. La relation réelle est `metadata.ownerReferences`.

```
Deployment
    │  OwnerReference
    ▼
ReplicaSet
    │  OwnerReference
    ▼
Pod
```

Le Pod pointe vers son ReplicaSet, le ReplicaSet vers son Deployment. Les noms **reflètent** cette hiérarchie ; Kubernetes utilise les ownerReferences.

## Noms générés

Les ressources créées par un contrôleur reçoivent un nom dérivé du parent.

**ReplicaSet** : `<deployment>-<hash-du-template>`

```
nginx
    ↓
nginx-7f9b867795
```

Le hash est calculé à partir de `spec.template`. Toute modification du template (image, variables d'environnement, volumes…) produit un **nouveau** ReplicaSet. C'est ce qui permet les rolling updates et les rollbacks.

**Pod** : `<replicaset>-<identifiant-aléatoire>`

```
nginx-7f9b867795-vkmtr
```

Le suffixe garantit l'unicité des Pods d'un même ReplicaSet.

## Garbage collection

Supprimer le propriétaire supprime les enfants.

```
kubectl delete deployment nginx
        ↓
Deployment → ReplicaSet → Pods
```

On ne supprime en général que la ressource **racine**.

## Deux types de modifications

Toutes les modifications d'un Deployment n'ont pas le même impact.

**Suppression d'un Pod** — le Deployment n'intervient pas. Le ReplicaSet reste valide.

```
Suppression d'un Pod
        ↓
ReplicaSet Controller
        ↓
Réconciliation
        ↓
Création d'un nouveau Pod
```

**Modification du template** (ex. `nginx:1.29` → `nginx:1.30`) — le ReplicaSet ne gère pas les changements de version. C'est le Deployment.

```
kubectl apply
        ↓
API Server
        ↓
Deployment Controller
        ↓
Nouveau ReplicaSet
        ↓
Nouveaux Pods
        ↓
Rolling Update
```

---

# Taints et tolerations

Un **taint** est une règle sur un Node : certains Pods ne doivent pas y être planifiés.

```
node-role.kubernetes.io/control-plane:NoSchedule
```

Un Pod n'est planifié sur ce Node que s'il a une **toleration** correspondante. Sans toleration, le Scheduler évite le Node.

K3s n'applique aucun taint sur le control-plane par défaut, afin de permettre l'exécution des applications sur un cluster à un seul nœud.

---

# Stockage

Comme pour le réseau (Service), Kubernetes sépare l'exécution de l'application de la gestion de ses données.

Les Pods sont éphémères. Ils peuvent être supprimés, recréés ou déplacés à tout moment. **Les données ne doivent jamais appartenir au Pod.**

## Le problème

Un Pod a son propre système de fichiers (`/etc`, `/var`, `/tmp`, `/app`…). Tout ce qui y est écrit disparaît avec le Pod.

```
Pod PostgreSQL
        ↓
Base de données
        ↓
Suppression du Pod
        ↓
Toutes les données sont perdues
```

Incompatible avec une application persistante.

## Principe

Le stockage est **extérieur** au Pod. Le Pod ne possède pas les données : il utilise un volume fourni par Kubernetes.

```
         Pod
    ┌────────────┐
    │ PostgreSQL │
    └─────┬──────┘
          │
          ▼
   Volume persistant
          │
          ▼
       Données
```

Le Pod peut disparaître. Le volume continue d'exister.

## PersistentVolumeClaim (PVC)

**Rôle** — exprimer un besoin de stockage (capacité, mode d'accès, StorageClass). Le PVC décrit l'état désiré. Il ne crée pas le volume.

**Responsable de :**

- demander une capacité ;
- décrire les besoins de l'application.

**Ne fait pas :**

- ne crée pas lui-même le volume ;
- ne connaît pas l'infrastructure sous-jacente ;
- ne connaît pas le chemin physique des données.

## StorageClass

**Rôle** — décrire **comment** Kubernetes doit créer un volume (politique de provisionnement).

Exemples : créer un dataset ZFS, un partage NFS, un volume Ceph, un disque cloud.

**Responsable de :** définir la méthode et les paramètres de création.

**Ne fait pas :** ne contient aucune donnée, ne représente aucun volume, ne connaît pas les applications.

## PersistentVolume (PV)

**Rôle** — représenter un volume **réellement disponible** (dataset ZFS, NFS, Ceph, EBS…).

**Responsable de :** représenter ce volume et être associé à un PVC.

**Ne fait pas :** ne décide pas quand créer un volume, ne connaît pas les applications.

## Dynamic provisioning

L'application crée un PVC (« je veux 20 Go »). Kubernetes trouve une StorageClass. Celle-ci crée automatiquement un PV, ensuite lié au PVC. Le développeur n'a pas à connaître l'emplacement physique.

```
Application
      │
      ▼
PersistentVolumeClaim
      │  « Je veux 20 Go »
      ▼
StorageClass
      │  « Voici comment créer un volume »
      ▼
PersistentVolume
      │  représente le stockage réel
      ▼
Dataset ZFS / NFS / Ceph / Cloud
```

## Séparation des responsabilités

| Ressource | Responsable de | Ne fait pas |
|-----------|----------------|-------------|
| Pod | Exécuter les conteneurs | Stocker durablement les données |
| PVC | Décrire le besoin de stockage | Créer le volume |
| StorageClass | Décrire comment créer un volume | Stocker des données |
| PV | Représenter un volume disponible | Décider quand il doit être créé |

Même philosophie que le reste de Kubernetes :

| Besoin | Exprime le besoin | Satisfait le besoin |
|--------|-------------------|---------------------|
| Exécuter une application | Deployment | ReplicaSet + Pod |
| Communiquer | Service | EndpointSlice Controller |
| Stocker des données | PVC | StorageClass + PV |

Dans les trois cas : le développeur décrit ce qu'il souhaite ; Kubernetes décide comment le satisfaire.

---

# Configuration des applications

Le Deployment décrit **comment lancer** l'application. La configuration vit dans des ressources spécialisées. On peut la modifier sans mélanger les responsabilités.

Le Deployment ne connaît pas les valeurs. Il connaît uniquement les ressources qui les fournissent.

```
Deployment
        │
        ├────────► ConfigMap
        │
        └────────► Secret
```

Avantages : séparation des responsabilités, réutilisation par plusieurs Pods, rotation des secrets sans retoucher le manifeste principal, lisibilité.

## ConfigMap

Données **non sensibles** : hôte de base, port, nom de base, niveau de logs, fuseau horaire, paramètres fonctionnels. Ne lance aucune application.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vaultwarden-config
data:
  DATABASE_HOST: postgres
  DATABASE_PORT: "5432"
  DATABASE_NAME: vaultwarden
  DATABASE_USER: vaultwarden
  LOG_LEVEL: INFO
  TZ: Europe/Paris
```

## Secret

Données **sensibles** : mots de passe, clés API, jetons, certificats.

Un Secret Kubernetes **n'est pas chiffré par défaut**. Les données sont encodées en Base64. Le chiffrement au repos est une option à activer explicitement. Les vraies valeurs ne sont pas versionnées dans ce dépôt (voir [Architecture.md](Architecture.md)).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vaultwarden-secret
stringData:
  DATABASE_PASSWORD: "********"
  ADMIN_TOKEN: "********"
  JWT_SECRET: "********"
```

## Injection

Le Pod ne lit jamais directement un ConfigMap ou un Secret. Il **référence** ce qu'il veut utiliser. Le **kubelet** injecte dans le conteneur : variables d'environnement, ou fichiers montés.

```
Deployment
        ↓
Pod
        ↓
Référence ConfigMap
        ↓
Référence Secret
        ↓
kubelet injecte
```

| Ressource | Contenu |
|-----------|---------|
| Deployment | Image, ports, volumes, CPU/RAM, **références** vers ConfigMaps et Secrets |
| ConfigMap | Configuration non sensible |
| Secret | Mots de passe, jetons, clés, certificats |

Le Deployment ne contient idéalement aucune donnée métier.

## Exemple : Vaultwarden

| Ressource | Contenu |
|-----------|---------|
| Deployment | Image, volumes, ports, références `vaultwarden-config` et `vaultwarden-secret` |
| ConfigMap | `DATABASE_HOST`, port, nom, user, `LOG_LEVEL`, `TZ` |
| Secret | mot de passe, `ADMIN_TOKEN`, `JWT_SECRET` |

## Composition d'une application

Une application n'est pas un seul objet. C'est un ensemble de ressources qui collaborent.

```
                    Deployment
                         │
         ┌───────────────┼────────────────┐
         │               │                │
         ▼               ▼                ▼
     ReplicaSet      ConfigMap        Secret
         │
         ▼
        Pod
         │
         ├──────────────► PVC
         │
         ▼
      Service
         │
         ▼
   EndpointSlice
```

---

# Vue d'ensemble

Les ressources que l'on **écrit** (Deployment, Service, PVC) sont déclaratives : elles expriment un besoin. Celles **en dessous** (ReplicaSet, EndpointSlice, PersistentVolume…) sont créées ou maintenues par Kubernetes. C'est l'idée la plus fondamentale du système.

```
                           Développeur
                                │
                                ▼
                     Décrit un état désiré
                                │
        ┌───────────────┬───────────────┬───────────────┐
        ▼               ▼               ▼
  Deployment          Service          PVC
        │               │               │
        ▼               ▼               ▼
  ReplicaSet     EndpointSlice      StorageClass
        │                               │
        ▼                               ▼
       Pod                     PersistentVolume
        │                               │
        └───────────────┬───────────────┘
                        ▼
                 Infrastructure
```

---

# Principes

Fondamentaux qui reviennent partout :

1. **Déclaratif** — décrire l'état désiré, jamais les étapes.
2. **Réconciliation** — les contrôleurs comparent en permanence état désiré et état réel, et corrigent.
3. **Une responsabilité par ressource** — chaque objet a un rôle précis et délègue le reste.
4. **Abstractions stables** — IP, disque physique, mots de passe dans le manifeste sont remplacés par Service, PVC, ConfigMap, Secret.
5. **Composition** — une application est un ensemble de ressources qui collaborent, pas un seul objet.

Conséquences concrètes :

- **Les Pods sont jetables.** Aucune donnée importante dedans.
- **Les Services sont permanents.** On parle au Service, jamais au Pod.
- **Les volumes sont permanents.** Jamais d'écriture critique dans le filesystem du Pod.
- **Les labels relient les ressources.** Presque jamais par le nom.

