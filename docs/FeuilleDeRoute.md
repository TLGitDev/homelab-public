# Feuille de route

> Cible et ordre de travail. Ce n'est **pas** l'as-built.
>
> As-built : [Architecture.md](Architecture.md). Stockage : [Stockage.md](Stockage.md). Sauvegardes : [Sauvegardes.md](Sauvegardes.md). Vaultwarden : [Vaultwarden.md](Vaultwarden.md).

---

# Principe

Avancer par étapes **réversibles**, avec une base fiable, sans multiplier les services avant de maîtriser le stockage, les sauvegardes et le déploiement.

On respecte l'existant : Proxmox, ZFS, K3s, Argo CD, Vaultwarden. On ne repart pas de zéro. On ne migre pas toute l'infra pour uniformiser les outils.

Les phases ne sont pas une prison. On peut **étudier** en parallèle (comparer Gitea et Forgejo pendant la phase 0 ou 1). En revanche, un service qui **expose** quelque chose ou **stocke** des données importantes doit attendre que ses dépendances soient assez solides.

Ce sont des **idées d'ordre**, pas un règlement.

---

# Vue d'ensemble

```
Phase 0  Fiabiliser l'existant
    │
    ├── Phase 1  Organiser les données personnelles
    │       └── Phase 2  Sauvegarde Android
    │
    ├── Phase 3  Forge Git et CI/CD
    │       └── Phase 5  Site CV public
    │
    └── Phase 4  Multimédia
            │
            └── Phase 6  Accès distant et exploitation
```

La comparaison des forges peut commencer tôt. L'inventaire Android aussi. Les sauvegardes automatiques du téléphone ne sont pas « fiables » tant que le stockage cible et sa protection (phase 0–1) ne sont pas validés.

---

# Phase 0 — Fiabiliser l'existant

**Objectif** : récupérer données et services après une erreur, une panne disque ou une mauvaise manipulation.

**Dépendances** : aucune. Prérequis pour les données personnelles et les nouveaux services.

| Chantier | Actions | Critère |
|----------|---------|---------|
| Snapshots ZFS | Automatiser, rétention définie | Créés tout seuls ; restauration testée |
| Sauvegarde USB | Copie externe, idéalement déconnectée hors job | Restauration depuis l'USB OK |
| Vaultwarden | Restauration complète : données, config, secrets | Service récupérable sans l'ancienne instance |
| État du stockage | Pool, erreurs, espace, disques | Contrôles documentés, anomalies visibles |
| Documentation | Sauvegarde, restauration, dépannage | Les opérations essentielles se font à partir de la doc |

Un snapshot ZFS **n'est pas** une sauvegarde. Il faut une copie distincte, idéalement hors ligne. [Sauvegardes.md](Sauvegardes.md).

## Jalon actuel

- ⚙️ Snapshots ZFS : politique v1 écrite (zvol VW, 24h/7j) — pas activée — [Sauvegardes.md](Sauvegardes.md#snapshots-zfs--cible)
- ✅ Archives Vaultwarden : 1er tar auto 20 oct. + copie `pve` — [Vaultwarden.md](Vaultwarden.md#sauvegarde)
- ⚙️ USB / Restic (`backup-usb` ; restore d'une **archive**, pas du service)
- ✅ Restore isolée : technique 20 oct. ; login + coffre 21 oct. (HTTPS local)
- ⬜ Reprise réelle sur le zvol (procédure [écrite](Vaultwarden.md#reprise-réelle--non-testée), non exécutée)

---

# Phase 1 — Organiser les données personnelles

**Objectif** : savoir où vivent les données, qui y accède, comment elles sont protégées, **avant** d'installer un portail de fichiers.

**Dépendance** : phase 0 suffisamment validée.

- Catégories : documents, photos, vidéos, archives, projets, données applicatives, médias.
- Distinguer : synchroniser / archiver / sauvegarder.
- Datasets ZFS, montages, permissions, quotas si besoin.
- Stratégie de sauvegarde par catégorie (surtout l'irremplaçable).
- Besoin « NAS » : partages, plusieurs appareils, utilisateurs, protocoles.

**Décision encore ouverte** : partages réseau, Nextcloud, Syncthing, ou un mélange.

| Solution | Rôle | Limite |
|----------|------|--------|
| Partages réseau | Accès direct aux fichiers | Peu de sync mobile intégrée |
| Nextcloud | Portail, partage ; contacts / calendrier selon les apps | Plus à maintenir et à sauvegarder |
| Syncthing | Sync de dossiers entre appareils | Ni sauvegarde, ni portail documentaire |
| ZFS seul | Protection locale et organisation | Pas une UX complète |

**Critère** : organisation documentée, permissions testées, une première restauration de fichiers OK.

---

# Phase 2 — Sauvegarde Android

**Objectif** : procédure reproductible pour changer de téléphone ou récupérer après une perte.

**Dépendances** : phase 0 (protection) et phase 1 (stockage cible).

Aucune solution unique ne copie tout un Android. On sépare par type, et on **écrit les exceptions** plutôt que de promettre une image complète du téléphone.

| Données | Approche | Limite |
|---------|----------|--------|
| Photos / vidéos | Sync vers le serveur, puis backup indépendant | Vérifier les originaux |
| Documents / téléchargements | Sync ou transfert planifié | Répertoires exclus selon l'app |
| Contacts / calendrier | Export ou sync compatible | Restauration et doublons |
| SMS / appels | Outil dédié, export récupérable | OS, droits, version Android |
| WhatsApp | Sauvegarde officielle et/ou médias locaux | Les fichiers ≠ restauration officielle des conversations |
| Signal | Sauvegardes / transfert de la version installée | Données chiffrées et clés de restauration |
| Données d'apps | Inventaire + exports disponibles | Android bloque souvent les données privées |
| APK | Inventaire ; extraction si permise | Un APK n'embarque pas les données ni tous les extraits |
| Réglages du téléphone | Sauvegarde constructeur + procédure écrite | Dépend du fabricant et des protections |

Ordre utile :

1. Inventaire du téléphone, version Android, données à garder.
2. Automatiser photos / vidéos / documents ; vérifier l'arrivée sur le serveur.
3. Exports contacts, calendrier, SMS.
4. WhatsApp, Signal, apps prioritaires, chacun de leur côté.
5. Secrets, clés, codes de récupération dans un endroit sûr (pas dans Git).
6. Tester une restauration **sans** effacer l'original.

**Critère** : une matrice (méthode, fréquence, lieu, limites, dernier test de restauration) par type de donnée.

---

# Phase 3 — Forge Git et CI/CD

**Objectif** : centraliser projets, config non secrète du homelab et déploiements, puis automatiser progressivement.

**Dépendance** : phase 0. La comparaison peut commencer plus tôt. La forge retenue doit être sauvegardée **avant** d'y mettre des éléments essentiels.

On **garde** K3s et Argo CD pour ce qui y tourne déjà. On ne bascule pas automatiquement tout le futur sur Kubernetes : le mode de déploiement se choisit par besoin (VM, LXC, conteneurs, K3s).

## 3.1 Comparer Gitea et Forgejo

Décision **pas encore prise**. Critères à remplir au moment du choix (versions et CI réelles, pas de souvenir).

- [ ] Maintenance et gouvernance
- [ ] Fonctions Git (issues, PR, releases, registre, intégrations)
- [ ] CI/CD (workflows, runners, secrets, déclencheurs)
- [ ] Déploiement (hébergement, MAJ, migration, sauvegarde)
- [ ] Écosystème (doc, plugins, communauté)
- [ ] Coût opérationnel dans ce homelab

0 / 6 examinés. Liste de préparation, pas un résultat.

## 3.2 Chaîne de déploiement

1. Héberger la forge et protéger ses données.
2. Versionner manifests, configs non secrètes, procédures.
3. Runners isolés, moindre privilège.
4. Tests et contrôles automatiques.
5. Première appli de test.
6. Relier la CI à Argo CD quand GitOps est le bon outil.
7. Documenter la restauration de la forge et des runners.

**Critère** : un changement versionné passe les contrôles et se déploie de façon reproductible, avec un retour arrière.

---

# Phase 4 — Multimédia

**Objectif** : bibliothèque organisée, accessible, maintenable.

**Dépendances** : phases 0 et 1 (volumes et permissions **avant** les applis).

Services **visés**, pas déployés :

| Service | Rôle |
|---------|------|
| Jellyfin | Lecture / bibliothèque vidéo et musique |
| qBittorrent | Téléchargements ; isolation réseau ; chemins cohérents |
| Prowlarr | Indexeurs |
| Sonarr | Séries |
| Radarr | Films |
| Lidarr | Musique |
| Bazarr | Sous-titres |
| Recyclarr | Config Radarr / Sonarr |
| Navidrome | Candidat lecteur musique, si Jellyfin ne suffit pas |

Ordre utile : datasets et droits → Jellyfin (fichiers déjà là) → qBittorrent isolé → Prowlarr puis Sonarr / Radarr → Bazarr / Recyclarr → Lidarr → Navidrome si besoin → backups des **configs**.

Les médias récupérables n'ont pas le même besoin de backup que les photos ou documents irremplaçables. Les configurations et métadonnées, si.

**Critère** : un fichier de test suit le parcours prévu ; les configs se restaurent.

---

# Phase 5 — Site CV public

**Objectif** : profil, projets, homelab — **sans** données privées.

**Dépendance** : phase 3 pour le pipeline. Une première version statique peut se préparer avant.

- Dépôt versionné.
- Contenus publics seulement (CV, homelab, projets, extraits de doc).
- Génération + validation automatiques, puis déploiement.
- Exposition minimale, HTTPS.
- Relire dépôts publics, journaux, captures, doc : pas de secrets, pas d'IP internes inutiles, pas de tokens.

**Critère** : site public ; un commit valide déclenche un déploiement reproductible ; rien de sensible n'est publié.

---

# Phase 6 — Accès distant et exploitation

**Objectif** : plus simple à administrer, plus sûr au quotidien.

**Dépendances** : dès que plusieurs services sont en prod ; à approfondir après les phases 3–5.

- Rôles de Traefik, du tunnel Cloudflare, des accès LAN. [Cloudflare.md](Cloudflare.md), [ArgoCD.md](ArgoCD.md).
- Étudier WireGuard pour l'accès privé distant (**pas décidé**).
- Séparer services publics et interfaces d'admin.
- Contrôles utiles : dispo, disque, ZFS, sauvegardes — pas dix tableaux vides.
- Mises à jour, redémarrages, alertes pertinentes.
- Comptes, permissions, secrets, certificats, reprise : documentés.

**Critère** : les pannes importantes se voient ; l'admin reste privé ; les routines sont écrites.

---

# Décisions encore ouvertes

| Sujet | Décision | Quand |
|-------|----------|-------|
| Forge Git | Gitea vs Forgejo | Phase 1–3 |
| Stockage personnel | Partages, Nextcloud, Syncthing, ou mélange | Phase 1 |
| Sauvegarde Android | Outils par catégorie | Phase 2 |
| Hébergement d'un service | VM, LXC, Docker, K3s | Avant **chaque** service |
| Musique | Jellyfin seul ou + Navidrome | Phase 4 |
| Accès distant | Tunnel, VPN, périmètre Traefik | Phase 6 |
| Supervision | Indicateurs et alertes utiles | Phases 0 et 6 |

Pas d'ADR tant que le choix n'est pas tranché.

---

# Hors phases (plus tard)

Idées **gardées**, pas planifiées :

- Home Assistant
- Paperless
- Immich

L'onduleur n'est plus un chantier : il est en place et protège le serveur. [Materiel.md](Materiel.md).

---

# Idées de fonctionnement

Pas des règles strictes.

1. Un déploiement important à la fois, tant que le précédent n'est pas assez solide. L'étude en parallèle est bienvenue.
2. Sauvegarder avant une migration ou un changement de structure ; avoir un retour arrière.
3. Une sauvegarde non restaurée reste une inconnue.
4. Documenter **après** validation (choix, chemins, incidents).
5. Ne pas migrer un composant qui marche juste pour « tout mettre pareil ».
6. Données personnelles et interfaces d'admin : pas exposées « pour que ce soit plus simple ».
7. Avant un service : RAM, CPU, disque, backups, et le temps de le soigner.
