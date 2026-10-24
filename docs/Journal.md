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
