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

Chaque ressource répond à une question précise.

| Ressource | Responsabilité |
|-----------|----------------|
| Pod | Exécuter une application |
| Deployment | Maintenir le nombre de Pods souhaité |
| Service | Fournir une identité réseau stable |
| Ingress | Exposer les Services vers l'extérieur |
| Persistent Volume | Fournir un stockage persistant |
| Secret | Stocker des informations sensibles |
| ConfigMap | Stocker la configuration non sensible |

## Pod

Unité minimale d'exécution. Un ou plusieurs conteneurs, qui partagent : la même IP, le même namespace réseau, des volumes communs, le même cycle de vie.

Un Pod est **jetable** (ephemeral) : il peut être détruit puis recréé à tout moment.

Règle : un Pod = une responsabilité. Deux applications au cycle de vie indépendant → deux Pods (Vaultwarden et PostgreSQL séparés). Un sidecar (logs, proxy, sync) partage le Pod de l'application principale : même réseau, mêmes volumes, même cycle de vie.

## Deployment

Décrit l'état désiré d'une application : nombre de répliques, image, stratégie de mise à jour.

Il ne crée pas les Pods directement :

```
Deployment
    ↓
ReplicaSet
    ↓
Pods
```

## Service

Les Pods ont une IP éphémère. Le Service fournit une identité réseau **stable**. Les autres applications parlent au Service, pas aux Pods.

Le Service sélectionne les Pods via des labels.

## Labels

Métadonnées pour décrire et relier les ressources, avec un couplage faible.

```yaml
labels:
  app: vaultwarden
```

Usages : associer un Service à des Pods, sélectionner des ressources, organiser le cluster.

---

# Principes

- **Déclaratif** — décrire le résultat attendu.
- **Faible couplage** — API Server et labels.
- **Réconciliation** — corriger l'écart état désiré / état réel.
- **Responsabilité unique** — chaque ressource a un rôle identifié.
