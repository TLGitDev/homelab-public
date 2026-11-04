# Journal de bord

> Historique chronologique du projet.
>
> Chaque séance répond à quatre questions :
>
> - Qu'avons-nous voulu faire ?
> - Qu'avons-nous réalisé ?
> - Qu'avons-nous appris ?
> - Quelle est la prochaine étape ?
>
> Les sprints 1 à 3 ont été rédigés le jour même.
> Les sprints 4 à 8 ont été reconstitués le 2026-09-02 à partir de l'historique local Cursor (sauvegardes datées des fichiers Markdown). Ce sont les dates auxquelles le travail a été **documenté**. Sans Git, l'heure exacte des commandes sur le serveur n'est pas disponible. Les 30 août et 1er septembre 2026 n'ont laissé aucune trace de documentation.

## Sprint et changelog

Un **sprint** a un chapitre (objectif, réalisé, vérifs, prochaine étape). Il correspond à une séance d'infra, d'étude cadrée, ou de POC.

Le **changelog** (en bas) indexe aussi les jours où seule la documentation a bougé (extraction, ADR, précisions). Ces lignes n'ont pas forcément un numéro de sprint.

Exemple : ADR-008 le 4 octobre (changelog seulement) ; POC `tank/vmdata` le 6 octobre (sprint 19).

---

# 2026-08-27 — Sprint 1 : Validation matérielle

## Objectif

Assembler une plateforme matérielle entièrement fonctionnelle avant toute installation logicielle.

---

## Réalisé

### Assemblage

- Installation du Ryzen 7 5700G.
- Installation du ventirad AMD.
- Installation de 32 Go de DDR4.
- Installation du SSD NVMe WD SN7100 2 To.
- Installation des deux Seagate IronWolf Pro 8 To.
- Montage dans le Fractal Design Node 804.
- Installation de l'alimentation.
- Câblage complet du boîtier.
- Installation des ventilateurs.
- Installation des connecteurs du panneau avant.

---

## Vérifications

- ✅ Premier POST hors boîtier.
- ✅ BIOS accessible.
- ✅ CPU détecté.
- ✅ 32 Go de RAM détectés.
- ✅ SSD NVMe détecté sur M2_1.
- ✅ Deux IronWolf détectés sur SATA1 et SATA2.
- ✅ Tous les ventilateurs fonctionnent.
- ✅ USB 3.0 en façade fonctionnel.
- ✅ Bouton Power fonctionnel.
- ✅ Plateforme entièrement validée.

---

## Difficultés rencontrées

### SSD installé initialement sur M2_2

**Cause**

Le connecteur M2_1 était caché sous son dissipateur.

**Résolution**

Déplacement du SSD vers M2_1.

**Leçon**

Toujours vérifier l'ensemble des emplacements disponibles avant l'installation.

---

### Hub de ventilateurs

**Cause**

Les ventilateurs du boîtier ne tournaient pas.

**Résolution**

Le hub nécessitait une alimentation SATA dédiée.

---

### Connecteur USB 3.0

Recherche du bon header sur la carte mère avant branchement.

Validation du fonctionnement des ports USB de façade.

---

## Compétences acquises

- Assemblage complet d'un serveur.
- Bench Test.
- Diagnostic matériel.
- Utilisation du BIOS UEFI.
- Installation d'un SSD NVMe.
- Différence entre SATA alimentation et SATA données.
- Cable management.
- Montage d'un boîtier Fractal Design Node 804.

---

## État du projet

Matériel terminé.

Plateforme validée.

Aucun défaut matériel détecté.

---

## Décisions prises

- Utiliser le SSD NVMe comme disque système.
- Réserver les deux IronWolf au stockage.
- Utiliser un miroir ZFS (RAID1) pour les données.
- Installer l'onduleur uniquement lorsque le serveur sera installé à son emplacement définitif.

---

## Prochaine séance

Installation de Proxmox VE.

Objectifs :

- Comprendre ce qu'est un hyperviseur.
- Installer Proxmox.
- Configurer le réseau.
- Accéder à l'interface Web.
- Préparer le stockage.

---

# 2026-08-27 — Sprint 2 : Installation de Proxmox VE

## Objectif

Installer Proxmox VE et rendre le serveur accessible depuis le réseau local.

## Réalisé

- Téléchargement de l'ISO officielle de Proxmox VE.
- Création d'une clé USB bootable avec Rufus.
- Installation de Proxmox sur le SSD NVMe.
- Configuration initiale du serveur.
- Correction de la configuration réseau.
- Installation du serveur à son emplacement définitif.
- Premier accès réussi à l'interface Web.

## Vérifications

- ✅ Proxmox installé.
- ✅ Démarrage correct.
- ✅ Interface Web accessible.
- ✅ Réseau opérationnel.
- ✅ Accès conservé avec Proton VPN (option LAN activée).

## Difficultés rencontrées

### Configuration réseau incorrecte

Le serveur était configuré en `<réseau-installation>` alors que le réseau domestique est en `<réseau-lan>`.

Résolution :

- modification de `/etc/network/interfaces`
- adresse : `<ip-pve>/24`
- passerelle : `<ip-box>`

### VPN

Le VPN masquait la configuration réseau réelle du PC.

Après désactivation du VPN, le diagnostic a pu être réalisé correctement.

L'option d'accès au réseau local de Proton VPN a ensuite été activée.

## Compétences acquises

- Installation d'un hyperviseur bare metal.
- Création d'une clé USB bootable.
- Configuration réseau Linux.
- Diagnostic réseau.
- Première utilisation de Proxmox.

## Prochaine étape

Découverte de l'interface de Proxmox.
Compréhension du Datacenter, du Node, du stockage et du réseau avant la création de la première VM.

# 2026-08-28 — Sprint 3 : Mise en service de Proxmox

## Objectif

Comprendre l'architecture de Proxmox, finaliser sa configuration et préparer le serveur pour l'utilisation.

## Réalisé

- Découverte de l'interface d'administration Proxmox.
- Compréhension de la hiérarchie Datacenter → Node → Storage.
- Étude des stockages `local` et `local-lvm`.
- Analyse des disques physiques et des partitions.
- Configuration des dépôts APT.
- Activation du dépôt Proxmox No-Subscription.
- Désactivation des dépôts Enterprise.
- Diagnostic et correction de la configuration DNS.
- Diagnostic de la synchronisation NTP.
- Synchronisation correcte de l'heure via Chrony.
- Mise à jour complète du système.
- Premier redémarrage après mise à jour du noyau Linux.

## Vérifications

- ✅ Interface Web accessible.
- ✅ Dépôts fonctionnels.
- ✅ Synchronisation NTP opérationnelle.
- ✅ Heure système correcte.
- ✅ Aucune mise à jour restante.
- ✅ Serveur redémarré avec succès.

## Difficultés rencontrées

### DNS

Le serveur conservait l'ancien serveur DNS (`<ip-dns-installation>`) configuré pendant l'installation.

Conséquence :

- impossible de résoudre les noms de domaine.

Résolution :

- configuration du DNS vers `<ip-box>`.

### Synchronisation de l'heure

Chrony ne disposait d'aucune source NTP valide tant que le DNS était incorrect.

Après correction du DNS et redémarrage de Chrony :

- synchronisation NTP réussie ;
- validation des signatures APT.

## Compétences acquises

- Architecture Proxmox.
- Gestion des dépôts APT.
- Diagnostic DNS.
- Diagnostic NTP.
- Mise à jour d'un hyperviseur.

## Prochaine étape

Comprendre ZFS avant la création du premier pool miroir.

---

# 2026-08-29 — Sprint 4 : Étude de ZFS

> Reconstitué d'après l'historique Cursor (Architecture.md 10:23, Proxmox.md 10:24, Glossaire.md 10:26).

## Objectif

Comprendre ZFS avant de créer un pool, conformément à la prochaine étape du sprint 3.

## Réalisé

- Documentation de l'architecture ZFS : VDEV, pools, datasets.
- Distinction RAID classique vs ZFS, miroir vs sauvegarde.
- Checksums, self-healing, scrub.
- Schéma du futur pool `tank` (miroir IronWolf) ajouté dans Proxmox.md.
- Création de Glossaire.md (laissé en brouillon le jour même).

## Vérifications

- Aucun pool ZFS créé ce jour : le stockage système est encore ext4 + LVM-Thin.
- Les compétences ZFS passent en 🟡 (compris, pas encore mis en œuvre).

## Compétences acquises

- Architecture ZFS (théorie).
- VDEV, pools, datasets.
- Checksums et self-healing.

## Prochaine étape

Passer de la théorie LXC / services à un premier conteneur.

---

# 2026-08-31 — Sprint 5 : LXC et conventions

> Reconstitué d'après l'historique Cursor (Architecture.md 10:37, Competences.md 10:38–10:42).

## Objectif

Définir comment les services seront isolés, nommés et adressés avant d'en installer un.

## Réalisé

- Architecture logique : un service = un LXC Debian.
- Conventions de nommage (hostname = nom du service).
- Première ébauche du plan d'adressage.
- Compétence « Création d'un conteneur LXC » passée en 🟢.

## Difficultés / dette

Le plan d'adressage a inscrit Proxmox en `<ip-pve-prévue>` alors que le nœud est en `<ip-pve>` depuis le sprint 2. Cette erreur n'a été identifiée que le 2 septembre.

## Compétences acquises

- Conteneurs LXC.
- Séparation des responsabilités.
- Plan d'adressage (à corriger).

## Prochaine étape

Déployer l'accès distant sans ouvrir de ports.

---

# 2026-08-31 — Sprint 6 : Cloudflare Tunnel et Access

> Reconstitué d'après l'historique Cursor (Architecture.md 13:23–14:13, Competences.md 14:14–14:15).

## Objectif

Rendre Proxmox accessible hors du LAN sans redirection de port, avec authentification forte.

## Réalisé

- LXC dédié `cloudflare` (CT 100) pour `cloudflared` uniquement.
- Cloudflare Tunnel (connexion sortante).
- Route `proxmox.labo.example` → `https://<ip-pve>:8006`.
- Cloudflare Access : email autorisé, OTP, MFA TOTP (KeePassXC).
- Principes documentés : défense en profondeur, refus par défaut, installer ≠ configurer.

## Vérifications

- ✅ Tunnel et Access documentés comme opérationnels.
- ✅ MFA activée.
- ✅ Compétences Cloudflare Tunnel, Access, MFA passées en 🟢.

## Compétences acquises

- Cloudflare Tunnel.
- Cloudflare Access.
- MFA.
- systemd / gestion de services.
- Bridge Linux.

## Prochaine étape

Stratégie de sauvegarde, puis aligner le stockage système sur ZFS.

---

# 2026-09-02 — Sprint 7 : Sauvegardes et incident IP

> Reconstitué d'après l'historique Cursor (Architecture.md 10:15).

## Objectif

Distinguer RAID, snapshots et sauvegardes, et fixer des objectifs RTO / RPO.

## Réalisé

- RTO : 1 journée. RPO : 24 heures.
- Stratégie en couches : miroir ZFS → snapshots → sauvegardes Proxmox (USB) → hors site (futur).
- Retour d'expérience : erreur 502 du tunnel.

## Difficultés rencontrées

### 502 Bad Gateway sur le tunnel Proxmox

**Hypothèse initiale**

Problème de certificat TLS.

**Diagnostic**

Depuis le LXC Cloudflare : `curl -vk https://<ip-pve>:8006` → *No route to host* sur l'adresse prévue (`.10`).

**Cause réelle**

Proxmox écoute en `<ip-pve>`, pas `<ip-pve-prévue>`.

**Leçon**

Vérifier IP, ports et connectivité avant de modifier une configuration complexe.

## Compétences acquises

- RAID ≠ snapshot ≠ sauvegarde.
- Diagnostic par hypothèses (cause racine : mauvaise IP).

## Prochaine étape

Corriger le stockage système : Proxmox est encore sur ext4 + LVM-Thin.

---

# 2026-09-02 — Sprint 8 : Réinstallation de Proxmox sur ZFS

> Reconstitué d'après l'historique Cursor (Architecture.md 11:58). Le récit de réinstallation reste dans ce journal ; l'état ZFS est dans [Stockage.md](Stockage.md).

## Objectif

Aligner le stockage système sur ZFS tant qu'aucune donnée critique n'est hébergée.

## Réalisé

- Audit : installation d'origine en ext4 + LVM-Thin.
- Réinstallation de Proxmox sur ZFS (`rpool` sur le NVMe).
- Organisation : `ROOT/pve-1`, `data/subvol-100-disk-0`, `var-lib-vz`.
- Feuille de route (sauvegardes, pool IronWolf, services).

## Vérifications

- ✅ `rpool` décrit comme pool système.
- ✅ Séparation NVMe (système / LXC) vs IronWolf (données, futur).
- ⬜ Pool `tank` (2×8 To) non créé.
- ⬜ Sauvegardes non mises en œuvre.

## Leçon

Il est préférable de perdre une heure au début d'un projet qu'une semaine plusieurs mois plus tard.

## Compétences acquises

- Pools ZFS (mise en œuvre système).
- Datasets.
- Décision de réinstaller plutôt que de migrer à chaud.

## Prochaine étape

- Mettre en œuvre les sauvegardes Proxmox et tester une restauration.

---

# 2026-09-07 — Sprint 9 : Pool `tank`

## Objectif

Créer le pool de données ZFS en miroir sur les deux IronWolf, distinct de `rpool`.

## Réalisé

- Pool `tank` : VDEV miroir, 2×8 To.
- Séparation confirmée : `rpool` = infrastructure, `tank` = données.
- Aucun dataset de service créé : un dataset n'apparaît que s'il y a un besoin réel (snapshots, quotas, propriétés, frontière logique). Sinon, un répertoire suffit.
- Documentation : hiérarchie ZFS, VDEV, bonnes pratiques (un VDEV ne se transforme pas après création).

## Vérifications

- ✅ `tank` créé.
- ✅ `rpool` inchangé (Proxmox + LXC cloudflare).
- ✅ `tank` vide (pas de dataset anticipé).
- ⬜ Sauvegardes Proxmox non mises en œuvre.

## Compétences acquises

- Création d'un pool ZFS en miroir.
- Distinction dataset / répertoire.
- Structure des VDEV figée à la création.

## Prochaine étape

Sauvegardes Proxmox, puis les services (datasets au moment du besoin).

---

# 2026-09-16 — Sprint 10 : Étude de Kubernetes

## Objectif

Comprendre le problème que Kubernetes résout, son modèle déclaratif et ses ressources, avant toute installation.

## Réalisé

- Chaîne Linux nu → Docker → Kubernetes (orchestration, pas un remplacement de Docker).
- État désiré vs état réel, réconciliation, API Server comme source de vérité.
- Contrôleurs, watches, work queues : système orienté état, pas événements.
- Ressources : Pod, Deployment, ReplicaSet, Service, labels, sidecar.
- Méthode d'apprentissage rappelée : commandes en dernier.

## Vérifications

- ✅ Théorie documentée dans [Kubernetes.md](Kubernetes.md).
- ⬜ Aucun cluster installé.

## Compétences acquises

- Concepts Kubernetes (🟡, pas encore mis en œuvre).
- Distinguer Docker (isolation) et Kubernetes (orchestration).

## Prochaine étape

Pratiquer Kubernetes (cluster) lorsque la plateforme sera justifiée, sans anticiper de ressources inutiles.

---

# 2026-09-19 — Sprint 11 : Ressources Kubernetes (Pod, ReplicaSet, Deployment)

## Objectif

Clarifier qui fait quoi, qui réagit à quel événement, et comment les objets sont liés.

## Réalisé

- Pod / ReplicaSet / Deployment : rôle, responsabilités, limites.
- Service (ClusterIP), labels, selectors, EndpointSlice.
- Schémas Deployment → Pod et Service → EndpointSlice.
- Table « qui réagit à quoi » (y compris EndpointSlice).
- `ownerReferences` : Kubernetes ne relie pas les objets par leur nom.
- Taints / tolerations ; K3s sans taint control-plane (cluster 1 nœud).
- Premiers exercices : Pods jetables, découplage, labels, réconciliation.

## Vérifications

- ✅ Documenté dans [Kubernetes.md](Kubernetes.md).
- ⬜ Cluster **homelab** non installé (exercices à part).

## Prochaine étape

Poursuivre la pratique, sans déployer Kubernetes sur le homelab tant que ce n'est pas justifié.

---

# 2026-09-20 — Sprint 12 : Stockage Kubernetes (PVC, PV, StorageClass)

## Objectif

Comprendre pourquoi les données ne doivent pas appartenir au Pod, et quelles ressources expriment / satisfont un besoin de stockage.

## Réalisé

- Filesystem du Pod = éphémère ; volume extérieur = persistant.
- PVC (besoin), StorageClass (comment créer), PV (volume réel), provisionnement dynamique.
- Parallèle Deployment / Service / PVC : le développeur déclare, Kubernetes concrétise.
- Schéma d'ensemble : ressources écrites vs ressources maintenues par le cluster.

## Vérifications

- ✅ Documenté dans [Kubernetes.md](Kubernetes.md).
- ⬜ Cluster homelab non installé.

## Prochaine étape

Continuer les déploiements d'exercice (volumes) sans anticiper Kubernetes sur le homelab.

---

# 2026-09-21 — Sprint 13 : Anatomie des manifestes

## Objectif

Lire un YAML Kubernetes comme une description d'état désiré, pas comme un script.

## Réalisé

- Structure commune : `apiVersion`, `kind`, `metadata`, `spec`.
- `spec.template` = modèle de Pod, pas un Pod.
- `containerPort` décrit, n'ouvre pas ; ports nommés pour découpler les Services.
- Hash du template → nouveau ReplicaSet (rolling update / rollback).
- Deux impacts : suppression d'un Pod (ReplicaSet) vs changement de template (Deployment).
- Garbage collection via ownerReferences : on supprime la racine.
- Cycle d'une requête : DNS → Service (ClusterIP) → EndpointSlice → Pod.

## Vérifications

- ✅ Documenté dans [Kubernetes.md](Kubernetes.md).
- ⬜ Cluster homelab non installé.

## Prochaine étape

Poursuivre les exercices, sans déployer Kubernetes sur le homelab tant que ce n'est pas justifié.

---

# 2026-09-21 — Sprint 14 : ConfigMap, Secret et composition d'une application

## Objectif

Séparer le « comment lancer » (Deployment) de la configuration (ConfigMap / Secret).

## Réalisé

- ConfigMap vs Secret ; Secret = Base64, pas un coffre-fort.
- Injection par le kubelet (env ou fichiers), jamais de lecture directe par le Pod.
- Exemple Vaultwarden (valeurs sensibles non versionnées).
- Schéma de composition : Deployment, ReplicaSet, Pod, Service, PVC, ConfigMap, Secret.
- Cinq principes de clôture des fondamentaux.

## Vérifications

- ✅ Documenté dans [Kubernetes.md](Kubernetes.md).
- ⬜ Cluster homelab non installé.

## Prochaine étape

Poursuivre les exercices. Kubernetes sur le homelab seulement s'il est justifié.

---

# 2026-09-25 — Sprint 15 : Conception d'une application Kubernetes

## Objectif

Passer des ressources isolées à la conception : besoins, dépendances, cycle de vie des données.

## Réalisé

- ConfigMap : rôle, injection (API Server → kubelet), n'écrire que ce qui change le défaut.
- Secret : `data` vs `stringData` ; Base64 ≠ chiffrement.
- Politique Git : Secrets d'exercice acceptés temporairement ; SOPS / Sealed Secrets / External Secrets plus tard.
- Table besoin → ressource ; Deployment au centre (ConfigMap, Secret, PVC).
- Un PVC si même cycle de vie (SQLite + pièces jointes Vaultwarden) ; séparés sinon.
- Traduction `docker run` → Deployment, PVC, Service, ConfigMap / Secret.

## Vérifications

- ✅ Documenté dans [Kubernetes.md](Kubernetes.md).
- ⬜ Cluster homelab non installé.

## Prochaine étape

Poursuivre les exercices de manifestes. Kubernetes sur le homelab seulement s'il est justifié.

---

# 2026-09-27 — Sprint 16 : Vaultwarden sur K3s

## Objectif

Déployer Vaultwarden sur K3s et le publier en `https://vaultwarden.labo.example` via le tunnel existant, sans port ouvert sur la box.

## Réalisé

- Manifestes : ConfigMap, Secret, PVC, Deployment, Service, Ingress (Traefik).
- Route Cloudflare `vaultwarden.labo.example` → `http://<ip-k3s-01>:80` (même tunnel `homelab`).
- HTTPS public = Cloudflare ; origin Traefik en HTTP.
- Chaîne vérifiée : dry-run, Pod Running, PVC Bound, curl Service, curl Host vers Traefik, navigateur.

## Vérifications

- ✅ Documenté dans [Vaultwarden.md](Vaultwarden.md).
- ✅ Accès Internet fonctionnel.
- ⬜ `ADMIN_TOKEN` encore une valeur de démonstration.
- ⬜ Sauvegarde du PVC non définie.

## Prochaine étape

Sécuriser le Secret ; documenter la sauvegarde du PVC.

---

# 2026-09-27 — Sprint 17 : SOPS + age pour ADMIN_TOKEN

## Objectif

Versionner le Secret Vaultwarden sans mettre `ADMIN_TOKEN` en clair dans Git.

## Réalisé

- SOPS 3.13.3 + age (PC et k3s-01). Même paire de clés ; privée hors dépôt.
- `.sops.yaml` : règle pour `kubernetes/vaultwarden/secret.yaml`.
- Édition via `sops` ; apply via `sops --decrypt | kubectl apply -f -`.
- Access : conservé pour Proxmox, pas devant Vaultwarden.
- Persistance vérifiée en recréant le Pod (PVC conservé).

## Vérifications

- ✅ Documenté dans [Vaultwarden.md](Vaultwarden.md).
- ✅ Fichier Git chiffré (`ENC[...]`).
- ⬜ Sauvegarde du PVC non définie.

## Prochaine étape

Documenter la sauvegarde du PVC.

---

# 2026-09-29 — Sprint 18 : Namespace vaultwarden, Sealed Secrets, Argo CD

## Objectif

Isoler Vaultwarden dans son namespace, versionner les secrets via Sealed Secrets, et laisser Argo CD synchroniser Git.

## Réalisé

- Namespace `vaultwarden` ; PVC neuf + restore depuis `/home/utilisateur/backups/vaultwarden/` (hashes vérifiés).
- SealedSecret resealé pour le nouveau namespace (changer le YAML ne suffit pas).
- Traefik 503 : ancien Ingress `default` + même hostname ; suppression → 200.
- Application Argo CD Synced/Healthy ; Deploy Key SSH en SealedSecret (`argocd-repo-homelab`).
- Nettoyage des ressources `default`.

## Vérifications

- ✅ Documenté dans [Vaultwarden.md](Vaultwarden.md).
- ✅ Coffre et données accessibles après migration.
- ⬜ Sauvegarde récurrente du PVC.

## Prochaine étape

Mettre en place une sauvegarde récurrente du volume Vaultwarden.

---

# 2026-10-06 — Sprint 19 : POC `tank/vmdata` et Local PV

## Objectif

Valider le chemin ZFS → Proxmox → VM → Linux → Local PV → PVC → Pod, sans migrer Vaultwarden.

## Réalisé

- Dataset `tank/vmdata` déclaré dans Proxmox (`zfspool: tank-vmdata`, `content images`, `sparse 1`).
- Volume de test 1 GiB `tank/vmdata/vm-9999-k8s-test`, attaché à `k3s-01` (`scsi1`, Virtio SCSI).
- ext4, montage `/var/lib/k3s-storage/k8s-test`.
- PV local statique + PVC Bound ; Pod a écrit `test.txt`, contenu identique dans la VM.
- Nettoyage intégral : plus aucune ressource de test. Vaultwarden inchangé (`local-path` / `rpool`).

## Vérifications

- ✅ Chaîne complète lecture / écriture.
- ✅ NFS et CSI ZFS écartés pour Vaultwarden à ce stade ([ADR-008](ADR/ADR-008-Vaultwarden-tank.md)).
- ⬜ Migration Vaultwarden.
- ⬜ Procédure de restauration (réattacher le zvol après perte de la VM).

## Compétences acquises

- zvol Proxmox sur `tank`.
- PersistentVolume local statique (`Retain`, `nodeAffinity`).

## Prochaine étape

Concevoir la migration Vaultwarden : sauvegarde préalable, nouveau volume sur `tank`, rollback via l'ancien PVC.

---

# 2026-10-14 — Sprint 20 : Migration Vaultwarden vers `tank`

## Objectif

Déplacer les données persistantes de Vaultwarden hors du disque système de `k3s-01`, vers un zvol sur `tank`, sans perdre GitOps ni le rollback.

## Réalisé

- Volume `tank/vmdata/vm-101-vaultwarden-data` (8 Gio), `scsi1`, ext4, `fstab` par UUID, montage `/var/lib/k3s-storage/vaultwarden`.
- PV `vaultwarden-zfs-pv` (`Retain`) + PVC `vaultwarden-zfs-pvc` Bound.
- Sauvegarde arrêtée `migration-2026-10-14` ; `integrity_check` ok ; SHA-256 source/destination identiques.
- Copie via Pod temporaire (ancien PVC en lecture seule). Deployment → `vaultwarden-zfs-pvc`.
- GitOps : `8ccecbc`, refresh, sync manuel. Argo CD Synced / Healthy. HTTP 200, coffre OK.
- Ancien PVC `vaultwarden-pvc` conservé (figé).

## Vérifications

- ✅ Chemin ZFS → VM → Local PV → Pod en production.
- ⬜ Sauvegardes régulières et copie hors `tank`.
- ⬜ Test de restauration (réattacher le zvol).
- ⬜ `ADMIN_TOKEN` en Argon2 PHC.

## Compétences acquises

- Migration de PVC avec rollback conservé.
- Local PV statique en GitOps (sync manuel).

## Prochaine étape

Formaliser les sauvegardes (SQLite cohérent), une copie hors `tank`, et un test de restauration. Ne pas supprimer l'ancien PVC tant que ce n'est pas en place.

---

# 2026-10-17 — Sprint 21 : `ADMIN_TOKEN` en Argon2id

## Objectif

Remplacer le token administrateur Vaultwarden en clair dans le Secret par un hash Argon2id, sans perdre `/admin`.

## Réalisé

- Hash via `/vaultwarden hash --preset owasp` (Pod temporaire, saisie interactive).
- Premier SealedSecret invalide (`invalid Base64 encoding`, CrashLoop) → revert `a499429`.
- Second hash resealé : `0e5f528`. Secret OK, mais le Pod déjà lancé gardait l'ancienne variable d'environnement.
- `rollout restart` du Deployment. Plus d'avertissement « plain text ». Coffre et `/admin` OK.

## Vérifications

- ✅ Argo CD Synced / Healthy (`0e5f528`).
- ✅ Logs sans « plain text ADMIN_TOKEN » ni erreur Base64 (fenêtre contrôlée).
- ⬜ Sauvegardes régulières, copie hors `tank`, test de restauration.
- ⬜ Suppression de l'ancien PVC `local-path` (politique `Delete` : ne pas le faire à la légère).
- ⬜ Nettoyage du Pod temporaire `vaultwarden-hash` s'il existe encore.

## Compétences acquises

- Hash PHC Argon2id pour Vaultwarden.
- Un Secret en `env` n'est pas rechargé sans redémarrage du Pod.

## Prochaine étape

Sauvegardes régulières (SQLite cohérent), copie hors `tank`, test de restauration. Ne pas supprimer l'ancien PVC tant que ce n'est pas en place.

---

# 2026-10-19 — Sprint 22 : Sauvegardes Vaultwarden automatisées

## Objectif

Archive cohérente quotidienne, transfert vérifié vers `pve`, rétention de 7 de chaque côté.

## Réalisé

- Script `backup-vaultwarden.sh` + timer 03:00 sur k3s-01. Test manuel OK (tar, `db.sqlite3` / `rsa_key.pem`, Deployment 1/1).
- Clé SSH dédiée `pve` → `utilisateur@k3s-01`. Script `pull-vaultwarden-backup.sh` + timer 03:15. SHA-256, publication atomique, rétention 7.
- `systemd-analyze verify` OK. Timers `active (waiting)`.
- USB / Restic déjà en place (restore de test, pas un tar de prod).

## Vérifications

- ✅ Job manuel local + pull idempotent sur l'archive déjà là.
- ⬜ Premier déclenchement automatique (20 octobre).
- ⬜ Pull d'une archive vraiment absente.
- ⬜ Scripts / units dans Git (hors secrets).
- ⬜ Restic à jour de `/tank/backups/k3s-01/`.
- ⬜ Restauration Vaultwarden depuis un tar de production.

## Documentation

[Vaultwarden.md](Vaultwarden.md#sauvegarde).

## Prochaine étape

Confirmer les timers, puis Restic USB et une restauration documentée.

---

# 2026-10-20 — Sprint 23 : Restore technique Vaultwarden

## Objectif

Vérifier qu'un tar de production démarre une instance **isolée**, sans toucher au volume live.

## Réalisé

- Archive timer `vaultwarden-2026-10-20_030012.tar` sur k3s-01 et `pve`, SHA-256 identique.
- `integrity_check` ok (29 tables, 119 ciphers, 1 utilisateur).
- Extraction `/var/tmp/…`, ns `vaultwarden-restore-test`, Pod 1.37.3, HTTP 200.
- Firefox : HTTPS obligatoire — login non testé.
- Nettoyage complet ; production inchangée.

## Vérifications

- ✅ Restore technique.
- ⬜ Connexion au compte / déchiffrement.
- ⬜ Reprise sur le zvol de prod.

## Documentation

[Vaultwarden.md](Vaultwarden.md#test-du-20-octobre-2026-technique).

## Prochaine étape

HTTPS isolé pour valider le coffre, ou procédure de reprise sur le volume de production. Rétention 7 à confirmer sur plusieurs jours.

---

# 2026-10-21 — Sprint 24 : Restore fonctionnel Vaultwarden

## Objectif

Valider login + déchiffrement sur une instance isolée en HTTPS local, sans toucher à la production.

## Réalisé

- Archive du 21 octobre 2026 (dernière sur `pve`) ; SHA vérifié.
- Certificat RSA jetable ; Pod 1.37.3 ; Rocket en HTTPS sur :80.
- `curl -sk https://localhost:18443/` → 200. Warning Firefox accepté.
- Login + 2FA ; coffre lisible (entrées, mots de passe).
- Avertissements HSTS Rocket : attendus, pas un échec.
- Nettoyage : namespace supprimé ; `sudo rm -rf` des `/var/tmp/vaultwarden-restore-test*` (créés en root) ; chemins absents ; prod `1/1` ; archives d'origine conservées.

## Vérifications

- ✅ Restore fonctionnel (coffre déchiffré).
- ✅ Nettoyage.
- ⬜ Reprise sur le zvol de prod.

## Documentation

[Vaultwarden.md](Vaultwarden.md#test-fonctionnel--https-local).

## Prochaine étape

Reprise sur le stockage de production : autre procédure. Rétention 7 à confirmer.

---

# Changelog

Index. Un sprint a aussi un chapitre plus haut. Une ligne sans numéro de sprint = évolution de doc seulement.

| Date | Évolution |
|------|-----------|
| 2026-08-27 | Sprint 1 : plateforme matérielle validée. Sprint 2 : Proxmox installé. |
| 2026-08-28 | Sprint 3 : dépôts, DNS, NTP, premières mises à jour. Architecture.md créé. |
| 2026-08-29 | Sprint 4 : étude ZFS (théorie). |
| 2026-08-31 | Sprints 5–6 : LXC, Cloudflare Tunnel, Access, MFA. |
| 2026-09-02 | Sprints 7–8 : stratégie de sauvegarde, incident IP, réinstall ZFS. |
| 2026-09-07 | Sprint 9 : pool `tank` (miroir 2×8 To). |
| 2026-09-16 | Sprint 10 : étude Kubernetes (théorie). |
| 2026-09-19 | Sprint 11 : ressources K8s, Service, EndpointSlice, taints. |
| 2026-09-20 | Sprint 12 : stockage K8s (PVC, PV, StorageClass). |
| 2026-09-21 | Sprint 13 : anatomie des manifestes, GC, cycle d'une requête. |
| 2026-09-21 | Sprint 14 : ConfigMap, Secret, composition d'une application. |
| 2026-09-25 | Sprint 15 : conception d'appli, cycle de vie des données, Docker → K8s. |
| 2026-09-27 | Sprint 16 : Vaultwarden sur K3s, Traefik, tunnel Cloudflare. |
| 2026-09-27 | Sprint 17 : SOPS + age, Access limité à Proxmox. |
| 2026-09-29 | Sprint 18 : namespace vaultwarden, Sealed Secrets, Argo CD. |
| 2026-09-30 | Extraire GitOps vers [ArgoCD.md](ArgoCD.md). |
| 2026-09-30 | ADR-004 K3s, ADR-005 Sealed Secrets, ADR-006 Argo CD. |
| 2026-09-30 | Clarifier : données Vaultwarden en `local-path`, pas sur `tank`. |
| 2026-09-30 | App of Apps (root auto-sync, workloads manuels). |
| 2026-09-30 | ADR-007 : exposition Argo CD, config hors `root`. |
| 2026-10-01 | API K8s privée ; backup local de la clé Sealed Secrets. |
| 2026-10-04 | ADR-008 : Vaultwarden sur volume bloc `tank` (cible, POC d'abord). |
| 2026-10-06 | Sprint 19 : POC `tank/vmdata` + Local PV validé, puis nettoyé. |
| 2026-10-14 | Sprint 20 : Vaultwarden migré sur zvol `tank` (Local PV). |
| 2026-10-17 | Sprint 21 : `ADMIN_TOKEN` Vaultwarden en Argon2id. |
| 2026-10-17 | Feuille de route cible (phases 0–6) dans [FeuilleDeRoute.md](FeuilleDeRoute.md). |
| 2026-10-19 | Sprint 22 : sauvegardes Vaultwarden (timers ; 1er run auto à confirmer). |
| 2026-10-20 | `backup-usb` (Restic, manifeste, tests) ; scripts/units dans `infrastructure/` (`056e89a`). |
| 2026-10-20 | Sprint 23 : restore technique Vaultwarden (HTTP 200 ; login ⬜). |
| 2026-10-21 | Sprint 24 : restore fonctionnel Vaultwarden (HTTPS local, 2FA, coffre lisible). |
| 2026-10-21 | Procédure de reprise réelle Vaultwarden (cas 1–3, non exécutée). |
| 2026-10-21 | Cible snapshots ZFS v1 (zvol Vaultwarden, 24h + 7j) — pas activée. |
| 2026-10-21 | Script/timers snapshots zvol Vaultwarden versionnés (pas encore installés sur `pve`). |
| 2026-10-21 | Timers snapshots zvol activés sur `pve` (1er horaire 12:00 ; daily 22 oct. 04:00). |
| 2026-10-21 | Snapshots horaires auto OK (`_1200`, `_1300`) ; daily timer encore ouvert. |
| 2026-10-21 | Noter : `backup-usb` du 20 oct. OK ; clé Sealed Secrets ≠ tars (pas dans Restic tant qu'elle n'est pas sous `/tank/backups`). |
| 2026-10-21 | Clé Sealed Secrets : copie manuelle `/tank/backups/k3s-01/sealed-secrets/` (périmètre `backup-usb`). |
| 2026-10-21 | Phase 0 assez solide ; démarrer la phase 1 : inventaire (document privé). |
| 2026-10-23 | Phase 1 : dataset `tank/documents` + première copie depuis le PC (originaux conservés). |
| 2026-10-23 | Pas de staging `/tank/backups/pc/documents`. Copier d'abord PC → `tank` ; élargir `backup-usb` à la fin. SMB plus tard. |
| 2026-10-23 | Dossier / phase 4 : `Multimedia` → `Mediatheques`. |
| 2026-10-23 | Phase 1 : `tank/images`, `musique`, `projets`, `videos` copiés depuis le PC (originaux conservés). |
| 2026-10-24 | `backup-usb` : plusieurs chemins (`/tank/backups` + dossiers perso live). Install `pve` / premier run ⬜. |
| 2026-10-24 | Premier `backup-usb` élargi OK : snapshot `<snapshot>`, 362983 fichiers, clé démontée. |
| 2026-10-24 | SMB LAN v1 : `smb.conf` (cinq partages, `utilisateur` / `perso`, bind `.50`). Install `pve` ⬜. |
| 2026-10-24 | SMB : viser LXC `samba` (CT 102, `.40`) ; procédure pour retirer Samba de `pve`. |
| 2026-10-24 | LXC `samba` as-built : cinq partages, Windows `\\<ip-samba>`, user `utilisateur` (sans l'IP). |
| 2026-10-24 | SMB : lecture + écriture Windows validées. |
| 2026-10-24 | Restore perso : `<snapshot>` → `/tmp`, SHA-256 identique. Phase 1 close. |
| 2026-10-24 | Phase 2 : inventaire (document privé). |
| 2026-10-24 | Android : LineageOS 22.2 / Android 15, aussi GrapheneOS. Périmètre : photos → `tank/images`, contacts, SMS si possible. |
| 2026-10-24 | Apps : liste déclarée. Obtainium (GitHub ou APK éditeur). Export JSON plus tard sur `tank`, pas dans Git. |
| 2026-10-24 | Apps : liste (document privé). Scanner QR hors périmètre. Aurora Store visé pour le reste, compte à part, pas le mode anonyme. |
| 2026-10-24 | Choix d'applications (document privé). LineageOS a microG. GrapheneOS : Play bac à sable, pas microG. Intégrité BASIC seulement. |
| 2026-10-24 | Procédure essai photo : `/tank/images/telephone`, Material Files, une copie, SHA-256. Pas jouée. |
| 2026-10-24 | `/tank/images/telephone` créé (`drwxrws--- utilisateur perso`). Copie depuis le tel ⬜. |
| 2026-10-24 | Material Files ouvre `\\<ip-samba>\images\telephone` (vide). Copie ⬜. |
| 2026-10-24 | Photo tel : copie vers `/tank/images/telephone`, SHA-256 identique. Reste de la pellicule et USB ⬜. |
| 2026-10-24 | Contacts : `.vcf` copié par SMB. Relecture sans import dans le carnet ⬜. |
| 2026-10-24 | Contacts : nombre de fiches du `.vcf` identique au carnet. Chemin non relevé. USB ⬜. |
| 2026-10-24 | `.vcf` et SMS (JSON) dans `/tank/documents/telephone/`. Appli SMS pas nommée. Relecture SMS ⬜. |
| 2026-10-24 | Carnet : Fossify Contacts. SMS : Fossify Messages. Pas figés. Le JSON SMS ne se rouvre qu'avec Fossify Messages. |
| 2026-10-24 | SMS : un message du JSON reconnu sur `pve`. Photo, `.vcf` et JSON hors USB ⬜. |
| 2026-10-24 | Copie photo en masse : Material Files lève `InterruptedException` (crédits SMB libres). Samba muet. Tas entier via le PC. |
| 2026-10-24 | Pellicule du tel déclarée copiée dans `/tank/images/telephone` (via le PC). SHA-256 sur une photo. USB ⬜. |
| 2026-10-24 | `backup-usb` bloqué : verrou Restic du PID 1382228 (11:57), processus absent. `restic unlock` (1 verrou). Run OK : snapshot `<snapshot>`, parent `<snapshot>`, 363180 fichiers, 197 nouveaux, ~470 Mio ajoutés. Clé restée montée. |
| 2026-10-24 | Restore `contacts_20261024_151331.vcf` depuis `<snapshot>` vers `/tmp`. SHA-256 identique, 52 fiches, live conservé. JSON vu : `Messages_20261024_151932.json`, pas restauré. `/tmp` effacé, clé démontée. |
| 2026-10-24 | Procédure d'installation GrapheneOS écrite (Obtainium, SMB, carnet, SMS, Play bac à sable). Pas jouée. |
| 2026-10-24 | Signal : `/tank/documents/telephone/SignalBackups` (`signal-backup-2026-10-24-18-46-57` + `files/`, 228 fichiers, 198 Mio). Clé hors dossier. Pas dans `<snapshot>`. Restore ⬜. |
| 2026-10-24 | Signal : restore du dossier `SignalBackups` sur le nouveau téléphone. OK. Pas recompté message par message. |
| 2026-10-24 | Firefox : installé sur le nouveau téléphone via Obtainium (HTML Mozilla, `download.cdn.mozilla.net`, trois liens intermédiaires, arm64). |
| 2026-10-24 | WhatsApp : transfert de téléphone à téléphone via l'appli. Pas de fichier sur `tank`. |
| 2026-10-24 | Bitwarden et Bitwarden Authenticator configurés sur le nouveau téléphone. Coffre = compte Vaultwarden. Codes hors `tank`. |
| 2026-10-24 | Contacts : importés sur le nouveau téléphone, sans Fossify Contacts. Déclaré complet. Appli non nommée. Fichier source : `contacts_20261024_151331.vcf` (52 fiches). |
| 2026-10-25 | GrapheneOS : Play Services installés. Compte Google à part ajouté à Aurora. Play Store non utilisé pour la liste. Aurora : liste des applications (document privé). Toutes déclarées fonctionnelles. |
| 2026-10-25 | Mullvad en place. Export Obtainium dans `/tank/documents/telephone/` (nom non relevé). `find` : `.vcf`, JSON SMS, JSON Obtainium. `ls` : `files` et `signal-backup-2026-10-24-18-46-57`. |
| 2026-10-25 | `backup-usb` OK : snapshot `<snapshot>`, parent `<snapshot>`. 363413 fichiers, 234 nouveaux, 0 modifiés, 154 dossiers nouveaux, 200,3 Mio ajoutés. Manifeste OK. `check` OK (10 snapshots). Clé démontée. |
| 2026-10-25 | Phase 2 close. Photos : sauvegarde suffisante, pas de restore du dossier. SMS : pas restaurés, pas de besoin ; `Messages_20261024_151932.json` reste dans `<snapshot>`. |
| 2026-10-27 | Phase 4 : `tank/mediatheques` créé (vide, 7,04 Tio libres). Groupe `media` GID 987. Dossiers en `2770` (`telechargements` aligné à 10:17). [Mediatheques.md](Mediatheques.md). |
| 2026-10-28 | Phase 4 : copie PC sur `tank/mediatheques`, 2,1 Tio. `chgrp` `media`, dossiers `2770`, fichiers `0660`. Détail par dossier non relevé. |
| 2026-10-28 | Jellyfin : LXC retenu (dataset hôte en bind mount ; K3s est une VM qui héberge déjà le coffre). Procédure CT 103 / `.60` écrite, pas jouée. [Mediatheques.md](Mediatheques.md). |
| 2026-10-28 | Jellyfin hors LAN, plus tard : Cloudflare Access, origine le LXC `.60:8096`. Pas dans le pas d'installation. |
| 2026-10-28 | CT 103 `jellyfin` running (`nesting=1`, `mp0` ro). Paquet 12.4+deb13. Compte dans `media`, `ls` des films OK, `/health` = `Healthy`. Assistant web pas fait. |
| 2026-10-28 | Jellyfin : scan terminé, un film lu jusqu'au bout. Titre non relevé. LAN seulement. |
| 2026-10-28 | qBittorrent : LXC 104 / `.70`, Mullvad WireGuard pour le seul compte du client. Montage limité à `telechargements/`. Procédure écrite, pas jouée. [Mediatheques.md](Mediatheques.md#qbittorrent--décision-28-oct). |
| 2026-10-28 | qBittorrent, constat : pas de CT 104, `.70` libre, `media` 987, `wireguard.ko` présent, 20 Gio libres. Blocs 1–5 pas lancés. |
| 2026-10-28 | CT 104 créé. Compte `qbittorrent` (UID 102) dans `media`. Écriture dans `complets/` OK. nftables `inet torrent` chargé après `restart`. Fichier Mullvad pas encore posé. |
| 2026-10-28 | qBittorrent : tunnel Mullvad OK (compte = Marseille, root = box, coupure `000`). `wg-quick@wg0` actif. Service qBittorrent actif, mot de passe au coffre. Pare-feu `104.fw` écrit. UI pas réglée. |
| 2026-10-28 | qBittorrent : image Debian `792723456` octets, `-rw-rw----`, groupe `media`, propriétaire hôte `100102`. Torrent et fichiers supprimés. `complets/` et `incomplets/` vides. |
| 2026-10-28 | qBittorrent ne retire pas le torrent en fin de download. Sonarr / Radarr le retireront après import réussi. Fichiers conservés. |
| 2026-10-28 | Prowlarr : LXC 105 `servarr` / `.80`, constat OK (`.80` libre, 20 Gio). Procédure écrite, pas jouée. Sonarr / Radarr dans ce CT ensuite. [Mediatheques.md](Mediatheques.md). |
| 2026-10-28 | CT 105 créé, `mp0` en écriture (sans `ro=1`), idmap du CT 103, `running`. Prowlarr pas installé. |
| 2026-10-28 | CT 105 : montage `nobody media`. Compte `prowlarr` UID 102. Archive `master` 92,2 Mio téléchargée, pas extraite. `tar \| head` : `stdout: write error` (tuyau fermé). |
| 2026-10-28 | Prowlarr extrait, service `active`, `curl` local `200`. Pare-feu `105.fw` et compte web pas faits. |
| 2026-10-28 | Prowlarr **2.7.0.5723**. `105.fw` écrit (9696). Compte `utilisateur`, Forms, Enabled, Allowed Hosts vide. Connecté. Pas d'indexeur. |
| 2026-10-28 | Sonarr : procédure écrite pour le CT 105 (branche `main`, `UMask=0007`, port 8989). Pas jouée. |
| 2026-10-28 | Sonarr : compte UID 103 dans `media`. Fichier d'essai `-rw-rw----` `100103 media`, effacé. Archive `main` 97,4 Mio, `gzip -t` OK, pas extraite. |
| 2026-10-28 | Sonarr extrait, service `active`, `curl` local `200`. Port 8989 et compte web pas faits. |
| 2026-10-28 | Sonarr **4.0.20.3014**. `105.fw` : 9696 et 8989. Connecté. Dossier racine et qBittorrent pas branchés. |
| 2026-10-28 | Sonarr : dossier `/mnt/mediatheques/series`. Client qBittorrent `.70:8080`, catégorie `tv-sonarr`, Remove Completed coché. Mappage `/mnt/telechargements/` → `/mnt/mediatheques/telechargements/` (barre finale, `Invalid Path` transitoire). Prowlarr pas relié. |
| 2026-10-28 | Prowlarr → Sonarr : Test réussi. Pas d'indexeur. Pas de série ajoutée. |
| 2026-10-28 | Sonarr : *Cold Case*, `/mnt/mediatheques/series/Cold Case`, 178,9 Gio. Saisons 4 à 7 complètes (22/22, 23/23, 18/18, 24/24). |
| 2026-10-28 | Radarr : procédure écrite pour le CT 105 (branche `master`, `UMask=0007`, port 7878). Pas jouée. |
| 2026-10-28 | Radarr : compte UID 104 dans `media`. Fichier d'essai `-rw-rw----` `100104 media`, effacé. Service `active`, `curl` local `200`. Port 7878 et compte web pas faits. |
| 2026-10-28 | Radarr **6.4.4.10685**. `105.fw` : 9696, 8989, 7878. Connecté. Dossier racine et qBittorrent pas branchés. |
| 2026-10-28 | Radarr : catégorie `radarr`. Test qBittorrent réussi. Test Prowlarr réussi. Pas d'indexeur. Pas de film ajouté. |
| 2026-10-28 | Radarr : *American History X*, `/mnt/mediatheques/films/American History X (1998)`, **Downloaded**, 1,9 Gio, `American History X (1998).mkv`. |
| 2026-10-28 | Bazarr : procédure écrite pour le CT 105 (venv, port 6767). Pas jouée. Pas de `pip` sur le Python du système. |
| 2026-10-29 | Bazarr **v1.6.2** sur le CT 105, port 6767. `active`, `curl` local `200`. Sonarr et Radarr testés. Profil `français`. Pas de fournisseur. `unrar` absent. |
| 2026-10-29 | Clés API Sonarr et Radarr régénérées, mises à jour dans Bazarr et Prowlarr. Tests déclarés bons. Valeurs hors de ce dépôt. |
| 2026-10-29 | Indexeur Knaben dans Prowlarr. Test réussi. Visible dans Sonarr et Radarr. |
| 2026-10-29 | Grab *Preacher* S03E01, catégorie `tv-sonarr`, aucun seed. EZTV : `eztvx.to` ne se résout pas. Indexeur non gardé. |
| 2026-10-29 | Même grab bloqué en **Downloading metadata** (0 o). Trois trackers Working, 1 seed chacun. Pairs `0 (2)`. Pas de connexion. |
| 2026-10-29 | Deuxième grab *Preacher* S03E01 : 852,7 Mio, **Stalled**, pairs `0 (2)`. Trackers Working à 1–2 seeds. |
| 2026-10-29 | Cinq grabs *Preacher* S03E01 en **Downloading metadata**, 0 o, pairs `0 (2)` ou `0 (3)`. Le décompte du site n'arrive pas dans qBittorrent. |
| 2026-10-29 | Transfert de port Mullvad sur le CT 104 : pas de modification. Mullvad l'a retiré le 29 mai 2023. Un port dans qBittorrent n'ouvre pas l'entrée. |
| 2026-10-29 | Essai AirVPN retiré avant d'être joué. Proton VPN sur le CT 104 : procédure écrite, pas jouée. DNS `10.2.0.1`, bail de port 60 s renouvelé par `proton-port`, clé Mullvad gardée. [Mediatheques.md](Mediatheques.md#proton--décision-29-oct). |
| 2026-10-29 | Proton VPN en service sur le CT 104. Serveur `FR#506`. Coupure : compte `000`, root `301`. `proton-port` actif, port `64509`. Depuis le PC, `TcpTestSucceeded : True` vers `<ip-sortie-vpn>:64509`. `wg0.conf.mullvad` gardé. |
| 2026-10-29 | Recyclarr : procédure écrite, pas jouée. Binaire v8.8.1 sur le CT 105. Profil français MULTi.VO, sans `quality_definition`, sans l'assigner. **Any** inchangé. [Mediatheques.md](Mediatheques.md#recyclarr--décision-29-oct). |
| 2026-11-01 | Recyclarr **v8.8.1** sur le CT 105, compte uid 106. `sync` : Sonarr 57 formats et 1 profil, Radarr 58 formats et 1 profil. `[French MULTi.VO] HD Bluray + WEB`. *Cold Case* et *American History X* restent sur **Any**. Pas de recherche. |
| 2026-11-01 | Lidarr : procédure écrite, pas jouée. CT 105, binaire **3.1.6.5079** (pas la préversion 3.2), port 8686. Import de `sons/` sans recherche. Navidrome non pris. [Mediatheques.md](Mediatheques.md#lidarr--décision-1er-nov). |
| 2026-11-01 | Lidarr **3.1.6.5079** en service sur le CT 105, compte uid 107, port 8686. `sons/` importé. Client qBittorrent catégorie `lidarr` testé. Prowlarr : **Test** réussi. Pas de recherche. |
| 2026-11-01 | Navidrome retenu, pas installé. Tunnel sans Access, comme Vaultwarden (`navidrome.labo.example` visé). Interfaces *arr : un nom chacune, Access, puis une page de liens. Pas joué. qBittorrent hors de ce pas. [Mediatheques.md](Mediatheques.md#navidrome-et-portail--choix-1er-nov). |
| 2026-11-02 | Navidrome : hébergement tranché, LXC 106 `<ip-navidrome>`, lecture seule, paquet 0.64.2, port 4533. Procédure écrite, pas jouée. Tunnel après la lecture LAN. [Mediatheques.md](Mediatheques.md#navidrome--décision-2-nov). |
| 2026-11-02 | Navidrome **0.64.2** en service sur le LAN, CT 106, `<ip-navidrome>:4533`. Compte web créé, nom non relevé. Bibliothèque déclarée visible. Tunnel pas créé. |
| 2026-11-02 | Route `navidrome.labo.example` → `http://<ip-navidrome>:4533`, sans Access. `https://navidrome.labo.example` : `302` vers `/app/`, titre Navidrome 0.64.2. |
| 2026-11-02 | Symfonium **15.1.0** lit Navidrome sur `https://navidrome.labo.example`. Tempus pas testé. Jalon Navidrome coché. |
| 2026-11-02 | Cinq noms *arr dans le tunnel `homelab`, Access devant, origine HTTP sur le CT 105. Login vérifié : Sonarr, Radarr, Prowlarr, Lidarr, Bazarr. Sonarr a d'abord répondu 502, origine corrigée. qBittorrent hors de ce pas. |
| 2026-11-02 | Page de liens des interfaces *arr abandonnée. Les cinq noms suffisent. Jalon coché. |
| 2026-11-02 | Configs des CT 103, 104, 105 et 106 dans `/tank/backups/mediatheques` (mode 600). Services relancés. Bazarr refait : la base est dans `/opt/bazarr/data`. Restauration lue, `integrity_check` `ok`. |
| 2026-11-02 | `backup-usb` : snapshot `<snapshot>`, parent `<snapshot>`. 10 fichiers nouveaux, 4,229 Gio ajoutés. Manifeste OK, `check` OK (12 snapshots). Clé démontée. `/tank/backups/mediatheques` est dans ce snapshot. |
| 2026-11-03 | Phase 3, critère gouvernance. Gitea 28.3.0 (1er nov.), TOC 3 élus et 3 nommés, MIT. Forgejo 17.0.1 et LTS 15.0.11 (26 oct.), Codeberg e.V., GPL depuis la v9, fork dur en 2024. Pas de choix. [Forge.md](Forge.md#maintenance-et-gouvernance). |
| 2026-11-03 | Phase 3, fonctions Git. Issues, PR, releases et registre des deux côtés. Piste Gitea. Pas de choix. [Forge.md](Forge.md#fonctions-git). |
| 2026-11-03 | Phase 3, CI. Actions des deux côtés, runners à part. Gitea : Docker, Kubernetes ou la machine. Forgejo : Docker, LXC ou la machine. Piste Gitea. Pas de choix. [Forge.md](Forge.md#ci). |
| 2026-11-03 | Phase 3, déploiement. Forge visée sur `k3s-01`, un pod, SQLite, zvol à part. Sauvegarde du dossier de données à l'arrêt. Miroir GitHub = dépôts seulement. Passage documenté Gitea → Forgejo jusqu'à Gitea 1.22. Pas joué. Piste Gitea. Pas de choix. [Forge.md](Forge.md#déploiement). |
| 2026-11-03 | Phase 3, écosystème. Pas de plugins des deux côtés. Docs courantes Gitea, docs versionnées Forgejo. `gt` 1.0.0 (2 nov.) pour Gitea 28. Outils Gitea décrits compatibles jusqu'à 1.22 côté Forgejo 17. Piste Gitea. Pas de choix. [Forge.md](Forge.md#écosystème). |
| 2026-11-03 | Phase 3, coût. Logiciels gratuits. SQLite, un pod. Gitea : 2 cœurs et 1 Go cités pour une petite équipe. Forgejo : pas de minimum publié, LTS calendaire. Enterprise non retenu. `k3s-01` 8 Gio, RAM libre non remesurée. Six critères examinés. Piste Gitea. Pas de choix. [Forge.md](Forge.md#coût-opérationnel). |
| 2026-11-03 | Phase 3, choix : Gitea, édition libre. But : workflow professionnel (demande de fusion, protection de branche, Actions, runner à part, Argo CD). Pas installé. [Forge.md](Forge.md#décision). |
| 2026-11-03 | Phase 3, jalons écrits. Le choix est coché. Hébergement, sauvegarde, dépôt d'essai, miroir, runner, workflow, Argo CD, Access et restauration : pas joués. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-03 | Idée notée, pas planifiée : page maison devant `agent` sur un pod de `k3s-01`, conversation et diffs, téléphone via Access. Après la forge. Pod sans le disque de la machine ni droit sur le cluster. [FeuilleDeRoute.md](FeuilleDeRoute.md#page-agent-plus-tard). |
| 2026-11-03 | Constat `k3s-01` : 7,5 Gio, 5,5 Gio disponibles, 4 cœurs, échange à 0. Disque `/` 51 Go libres. Nœud 2505 Mio (32 %). Vaultwarden 14 Mio. Pas de pod Gitea. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-03 | Constat VM 101 : `scsi0` système 64 Go, `scsi1` coffre 8 Go. `scsi2` libre. `tank/vmdata` : seul `vm-101-vaultwarden-data`, 4,93 Tio libres. Volume Gitea pas créé. |
| 2026-11-03 | Volume `tank/vmdata/vm-101-gitea-data` créé, 8 Go, creux. Attaché `scsi2`, `iothread=1`. `scsi0` et `scsi1` inchangés. Pas formaté. |
| 2026-11-03 | `k3s-01` : rescan SCSI, un seul disque 8 Go vide (`sdc`). ext4, étiquette `gitea-data`, UUID `<uuid-disque-gitea>`. Ligne `fstab` `defaults,noatime`. `sdb` (`vaultwarden-data`) non touché. `mount` lancé ; `findmnt` pas encore collé. |
| 2026-11-03 | Montage vérifié. `/var/lib/k3s-storage/gitea` sur `/dev/sdc`, ext4, `rw,noatime`, UUID `<uuid-disque-gitea>`, 7,4 Go libres. Coffre toujours sur `/dev/sdb`. Manifestes écrits, pas appliqués. Pas de pod. |
| 2026-11-03 | Gitea `1/1`, PVC lié, `integrity_check` `ok`. `INSTALL_LOCK`, inscription fermée, pages derrière un compte. Compte `admin`. Zéro dépôt. Adresse `http://<ip-k3s-01>:3000/` par port-forward. Jalon pod coché. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-03 | Archive `gitea-2026-11-03_180511.tar`, 2,3 Mio, mode 600, SHA-256 `<empreinte-vérifiée>`. Relue ailleurs : `ok`, compte `admin`, zéro dépôt. `SECRET_KEY` vide. Jalon sauvegarde pas coché. |
| 2026-11-03 | `SECRET_KEY` écrit à l'arrêt, 64 caractères. `INTERNAL_TOKEN` déjà là, 105. Archive `gitea-2026-11-03_180902.tar`, SHA-256 `<empreinte-vérifiée>`. Relue ailleurs : `ok`, clé présente, compte `admin`, zéro dépôt. Pod `1/1`. Jalon coché. Reste sur `k3s-01`, pas sur `pve`. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-03 | Dépôt `admin/homelab` poussé depuis le PC. Push direct vers `master` refusé. Demande de fusion n° 1 fusionnée, `ad9faf2`. `master` local suit toujours GitHub. Jalon coché. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-04 | Argo CD lit GitHub. `homelab` reste sur GitHub seul. Les futures applications : push Gitea, miroir vers un dépôt GitHub déjà créé, déploiement depuis cette copie. L'essai `admin/homelab` du 3 nov. est encore sur Gitea, non suivi. On le retire avec l'accès extérieur. [Forge.md](Forge.md#décision). |
| 2026-11-04 | Miroir push `admin/essai-miroir` vers `TLGitDev/essai-miroir`. Commit `e2e0eb6a` des deux côtés. Pas `homelab`. Jalon coché. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-04 | `gitea-service` passé en `LoadBalancer`. `<ip-k3s-01>:3000` répond `200` depuis `pve`, sans port-forward. `107` et `<ip-runner>` libres. Runner pas créé. |
| 2026-11-04 | Runner hors de `k3s-01` : le job exécute le script poussé, et un pod atterrirait sur la VM du coffre. CT 107 `runner` créé, `<ip-runner>`, non privilégié, 2 Gio, `running`. `curl` absent, jointure à la forge pas constatée. Binaire pas installé. Jalon pas coché. [Forge.md](Forge.md#décision). |
| 2026-11-04 | Depuis le CT 107, `http://<ip-k3s-01>:3000/` répond `200`. Binaire `gitea-runner` pas installé. Jalon pas coché. |
| 2026-11-04 | CT 107 : `gitea-runner` `v5.2.0`, checksum `OK`. Compte `gitea-runner` uid 999. Configuration écrite, mode 600. Pas enregistré. Jalon pas coché. |
| 2026-11-04 | Runner `runner` enregistré, `v5.2.0`, étiquette `host`. Service activé, `active` à 09:51:45 UTC. `.runner` en 644, 438 octets. Page Opérateurs pas encore vue. Jalon pas coché. |
| 2026-11-04 | `.runner` resserré en 600. Journal : `declare successfully`, libellés `[host]`. Page Runners : id 1, global, Idle, `now`. Jalon coché. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-04 | Workflow sur `admin/essai-miroir`, pas `homelab`. Actions du dépôt activées. CI n° 1, commit `0813dcc290`, `main`, vert en 2 s. Jalon coché. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-04 | Déploiement d'essai : `a6c4965` pose `version` `1`, `31fcdee` pose `2`. Rollback Argo vers `a6c4965`. Cluster relu à `1`, application `OutOfSync`. Jalon coché. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-04 | `gitea.labo.example` publié, origine `http://<ip-k3s-01>:3000`, Access devant. Page de connexion vue. Essai `admin/homelab` retiré, remote local `gitea` aussi. `essai-miroir` reste. `ROOT_URL` inchangée. Jalon coché. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-04 | Restauration forge à côté : `gitea-2026-11-04_150155.tar`, mode 600, SHA-256 `<empreinte-vérifiée>`. `ok`, `admin/essai-miroir`, clé 64, jeton interne 105. Pod `1/1`, disque en service intact. Runner pas joué. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
| 2026-11-04 | Restauration runner : copie `/var/backups/gitea-runner-2026-11-04.tar`, mode 600. `.runner` retiré puis remis, identique. `active`, `declare successfully`, `v5.2.0`, `[host]`. Jalon coché. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea). |
