# Glossaire

Définitions utilisées dans le homelab. Les niveaux de maîtrise sont dans [Competences.md](Competences.md).

---

## Virtualisation

### Hyperviseur

Logiciel qui permet d'exécuter plusieurs machines virtuelles ou conteneurs sur un même serveur physique.

### LXC (Linux Containers)

Technologie de virtualisation légère partageant le noyau Linux de l'hôte. Un LXC possède son propre système de fichiers, ses processus et son réseau, mais n'embarque pas son propre noyau.

### RootFS (Root Filesystem)

Disque système d'un conteneur Linux. Il contient Debian, les fichiers système et les applications installées.

### Template

Image d'un système Linux déjà installé servant de modèle pour créer rapidement de nouveaux conteneurs.

### Unprivileged Container

Conteneur exécuté avec des privilèges réduits afin d'améliorer la sécurité de l'hôte.

---

## Kubernetes

Cours : [Kubernetes.md](Kubernetes.md).

### API Server

Source de vérité du cluster. Toutes les ressources y sont enregistrées. Le YAML ne sert qu'à modifier cette source.

### Réconciliation

Boucle des contrôleurs : lire l'état désiré, observer l'état réel, corriger uniquement les écarts, recommencer.

### Pod

Unité minimale d'exécution. Un ou plusieurs conteneurs qui partagent IP, réseau, volumes et cycle de vie. Jetable : il peut être recréé à tout moment.

### ReplicaSet

Garantit N Pods identiques : les crée, les recrée s'ils disparaissent, en supprime s'il y en a trop. Ne gère pas les mises à jour de version.

### Deployment

Cycle de vie de l'application : ReplicaSet, rolling update, rollback, nombre de réplicas. Ne crée jamais les Pods directement.

### OwnerReference

Lien de propriété réel entre objets (`metadata.ownerReferences`). Kubernetes ne relie pas les ressources par leur nom.

### Ingress

Règle de routage HTTP (hostname, chemin) vers un Service. Prise en charge par un Ingress Controller (`ingressClassName`, ex. Traefik). As-built : [Vaultwarden.md](Vaultwarden.md).

### Service

Identité réseau stable (ClusterIP) devant des Pods à IP éphémère. Ne lance pas les Pods. Sélection par labels.

### Selector

Règle qui sélectionne les ressources portant certains labels (ex. `app: nginx`).

### EndpointSlice

Liste des Pods actuellement joignables pour un Service. Maintenue par le EndpointSlice Controller, pas par le Service lui-même.

### DNS Kubernetes

Nom stable d'un Service dans le cluster : `<service>.<namespace>.svc.cluster.local` (ex. `nginx.default.svc.cluster.local`).

### Taint / Toleration

Un taint sur un Node interdit d'y planifier des Pods, sauf ceux qui ont une toleration correspondante.

### apiVersion / kind / metadata / spec

Structure commune d'un manifeste. `spec` = état désiré. `metadata` = identité (nom, labels, ownerReferences…), pas le comportement.

### Pod template

`spec.template` n'est pas un Pod : c'est le modèle dont le ReplicaSet se sert pour en créer. Un hash de ce template entre dans le nom du ReplicaSet.

### containerPort

Décrit le port d'écoute. N'ouvre pas le port. Un nom (`http`) permet au Service d'utiliser `targetPort: http` sans coller au numéro.

### Garbage collection

Supprimer un propriétaire (`kubectl delete deployment …`) supprime ses enfants via les ownerReferences.

### Label

Métadonnée qui relie les ressources (ex. `app: vaultwarden`) sans les coupler fortement.

### Sidecar

Conteneur d'assistance dans le même Pod que l'application (logs, proxy, sync).

### ConfigMap

Configuration non sensible (hôte, port, niveau de logs…). Injectée dans le Pod par le kubelet (variables d'environnement ou fichiers). Ne lance aucune application.

### Secret

Données sensibles. Encodé en Base64, **pas chiffré** par défaut. Le Pod référence le Secret ; le kubelet injecte.

### SOPS / age

SOPS chiffre des fichiers (ex. un Secret YAML) pour Git. age fournit les clés. Clé publique dans `.sops.yaml` ; clé privée hors dépôt. As-built : [Vaultwarden.md](Vaultwarden.md#sops--age).

### data / stringData

Deux façons de remplir un Secret. `data` attend du Base64. `stringData` accepte le clair ; l'API Server encode.

### Cycle de vie des données

Critère pour partager un volume : ensembles créés, sauvegardés, restaurés et supprimés ensemble → un PVC. Sinon, volumes (et souvent déploiements) séparés.

### PersistentVolumeClaim (PVC)

Besoin de stockage exprimé par l'application (capacité, mode d'accès, StorageClass). Ne crée pas le volume.

### StorageClass

Politique de provisionnement : comment Kubernetes crée un volume (ZFS, NFS, Ceph, cloud…).

### PersistentVolume (PV)

Volume réellement disponible, associé à un PVC. Peut représenter un dataset ZFS, du NFS, etc.

---

## Réseau

### Bridge Linux (`vmbr0`)

Commutateur (switch) virtuel permettant aux VM et LXC de communiquer avec le réseau physique.

### Gateway (Passerelle)

Machine vers laquelle un ordinateur envoie les paquets destinés à un autre réseau (généralement la box Internet).

### MAC Address

Identifiant matériel unique d'une interface réseau. Il est utilisé au niveau du réseau local.

### CIDR (`/24`)

Notation indiquant la taille du réseau IP.

Exemple : `<ip-cloudflare>/24` signifie que le réseau est `<réseau-lan>` avec un masque `255.255.255.0`.

### Plan d'adressage

Organisation des adresses IP d'une infrastructure afin que chaque service possède une adresse fixe et facilement identifiable.

Le plan actuel est dans [Proxmox.md](Proxmox.md).

---

## Stockage

### ZFS

Système de fichiers et gestionnaire de volumes. Il regroupe disques, redondance, checksums, snapshots et compression.

Cours et état du homelab : [Stockage.md](Stockage.md).

### VDEV (Virtual Device)

Groupe de disques. C'est l'unité de protection des données dans ZFS (disque unique, miroir, RAIDZ…).

### Pool

Espace de stockage ZFS constitué d'un ou plusieurs VDEV. Il contient des datasets. Si un VDEV entier est perdu, le pool devient inutilisable.

### Dataset

Système de fichiers indépendant à l'intérieur d'un pool, avec ses propres propriétés (compression, quotas, snapshots, montage). L'espace est pris dynamiquement dans le pool : pas de taille fixée à l'avance comme une partition. On ne crée un dataset que s'il y a un besoin distinct (sinon un répertoire suffit).

### Checksum

Empreinte calculée pour chaque bloc. ZFS la recalcule à la lecture pour détecter une corruption silencieuse.

### Self-Healing

Sur un VDEV miroir, ZFS remplace automatiquement un bloc corrompu par la copie saine.

### Scrub

Lecture complète du pool pour vérifier tous les checksums et réparer les blocs corrompus lorsqu'une copie saine existe.

### Snapshot

Photo d'un dataset à un instant T, stockée sur le même pool. Utile pour revenir en arrière, ce n'est pas une sauvegarde.

---

## Système

### Scheduler

Composant du noyau Linux chargé de décider quel processus utilise le processeur à chaque instant.

### Oversubscription (CPU)

Technique consistant à attribuer plus de cœurs virtuels que le nombre de cœurs physiques disponibles, en s'appuyant sur le fait que tous les services n'utilisent pas le processeur en permanence.

### Swap

Espace disque utilisé lorsque la mémoire RAM vient à manquer. Il ne remplace pas la RAM mais sert de mémoire d'urgence.

### Thrashing

Situation où le système passe son temps à déplacer des données entre la RAM et le swap au lieu d'exécuter les applications. Le serveur reste fonctionnel mais devient extrêmement lent.

### OOM Killer (Out Of Memory Killer)

Mécanisme du noyau Linux qui termine automatiquement un ou plusieurs processus lorsqu'il n'y a plus suffisamment de mémoire disponible.

---

## Sécurité et accès

### Cloudflare Tunnel

Connexion sortante permanente du serveur vers Cloudflare. Permet d'exposer un service sans ouvrir de port sur le routeur.

Détail : [Cloudflare.md](Cloudflare.md).

### Cloudflare Access

Contrôle d'accès devant l'application : l'utilisateur s'authentifie chez Cloudflare avant que la requête n'atteigne le homelab.

### Principle of Least Privilege (Principe du moindre privilège)

Un service ne doit disposer que des droits strictement nécessaires à son fonctionnement.

### Separation of Concerns (Séparation des responsabilités)

Principe consistant à attribuer une seule responsabilité à chaque composant afin de simplifier la maintenance et d'améliorer la sécurité.

### Defense in Depth (Défense en profondeur)

Plusieurs couches de sécurité indépendantes. La défaillance d'une couche ne suffit pas à compromettre l'ensemble.

### Default Deny (Refus par défaut)

Tout accès est refusé tant qu'une règle ne l'autorise pas explicitement.

---

## Sauvegardes

### RTO (Recovery Time Objective)

Durée maximale acceptable pour remettre le service en état. Objectif actuel du homelab : 1 journée.

### RPO (Recovery Point Objective)

Quantité maximale de données que l'on accepte de perdre. Objectif actuel : 24 heures.

### RAID / Miroir

Protège contre la panne d'un disque. Ne protège pas contre une suppression, un ransomware ou une erreur humaine. Ce n'est pas une sauvegarde.
