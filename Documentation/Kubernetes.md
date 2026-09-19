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
| Persistent Volume | Fournir un stockage persistant |
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

# Principes

Observés dans la théorie et les premiers exercices :

- **Les Pods sont jetables.** Un Pod peut disparaître à tout moment. L'application doit continuer à fonctionner.
- **Les ressources sont découplées.** Aucune ressource ne connaît l'ensemble du système. Chacune n'a que ce qui concerne sa responsabilité.
- **Les labels remplacent les noms.** On ne recherche presque jamais un objet par son nom.
- **Tout repose sur la réconciliation.** Les ressources décrivent un état désiré. Les contrôleurs observent l'état réel et corrigent les écarts.
- **Déclaratif** — décrire le résultat attendu.
- **Responsabilité unique** — chaque ressource a un rôle identifié.

