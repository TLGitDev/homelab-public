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

Les noms ressemblent à une hiérarchie, ce n'est qu'une **convention** :

```
nginx
    ↓
nginx-7b9867795
    ↓
nginx-7b9867795-vkmtr
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

Observés dans la théorie et les premiers déploiements :

- **Les Pods sont jetables.** Ils peuvent être supprimés ou recréés à tout moment. Aucune donnée importante dedans.
- **Les Services sont permanents.** Identité réseau stable. On parle au Service, jamais au Pod.
- **Les volumes sont permanents.** Ils survivent aux Pods. Jamais d'écriture critique dans le filesystem du Pod.
- **Les ressources sont spécialisées.** Chacune a une responsabilité unique et délègue le reste.
- **Les labels relient les ressources.** On ne se retrouve presque jamais par le nom, plutôt par labels et selectors.
- **Tout repose sur l'état désiré.** Le développeur décrit un objectif. Les contrôleurs réconcilient.

