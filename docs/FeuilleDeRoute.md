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
    └── Phase 4  Mediatheques
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

## Jalons

Assez **solide** pour démarrer la phase 1. Rollback snapshot et reprise zvol : écrits, **non joués** sur la prod (volontaire).

- ✅ Snapshots zvol Vaultwarden : script + timers horaires (rétention 24) ; runs auto `_1200` / `_1300` — [Sauvegardes.md](Sauvegardes.md#snapshots-zfs)
- ⬜ Premier snapshot quotidien timer (22 oct. 04:00) et rétention 7 j sur la durée
- ⬜ Restauration par rollback snapshot (prod)
- ✅ USB / Restic : `backup-usb` (20 oct.) ; restore d'une archive testée
- ⬜ Rétention des snapshots Restic
- ✅ Restore isolée Vaultwarden (technique 20 oct. + login 21 oct.) — [Vaultwarden.md](Vaultwarden.md)
- ⬜ Reprise réelle sur le zvol de prod ([écrite](Vaultwarden.md#reprise-réelle--non-testée), non exécutée)
- ✅ Clé Sealed Secrets sous `/tank/backups` (périmètre USB)
- ✅ État du stockage documenté — [Stockage.md](Stockage.md)
- ✅ Documentation des opérations déjà faites (sauvegarde, restore isolée, USB)

---

# Phase 1 — Organiser les données personnelles

**Objectif** : savoir où vivent les données, qui y accède, comment elles sont protégées, **avant** d'installer un portail de fichiers.

**Dépendance** : phase 0 suffisamment validée.

- Catégories : documents, photos, vidéos, archives, projets, données applicatives, Mediatheques.
- Distinguer : synchroniser / archiver / sauvegarder.
- Datasets ZFS, montages, permissions, quotas si besoin.
- Stratégie de sauvegarde par catégorie (surtout l'irremplaçable).
- Besoin « NAS » : partages, plusieurs appareils, utilisateurs, protocoles.

**Décision** : Nextcloud / Syncthing **pas pris**. Accès Windows = **SMB** (LAN, LXC `samba` CT 102, `\\<ip-samba>`, user `utilisateur`). Copies PC → `tank` = faits (23 oct.). `backup-usb` élargi joué (24 oct.). Samba retiré de `pve`.

| Solution | Rôle | Limite |
|----------|------|--------|
| Partages réseau | Accès direct aux fichiers | Peu de sync mobile intégrée |
| Nextcloud | Portail, partage ; contacts / calendrier selon les apps | Plus à maintenir et à sauvegarder |
| Syncthing | Sync de dossiers entre appareils | Ni sauvegarde, ni portail documentaire |
| ZFS seul | Protection locale et organisation | Pas une UX complète |

**Critère** : organisation documentée, permissions testées, une première restauration de fichiers OK.

## Jalons

- ✅ Inventaire — (document privé)
- ✅ Datasets + copies PC (23 oct., originaux conservés) : `documents`, `images`, `musique`, `projets`, `videos`
- ✅ Décision : pas Nextcloud / Syncthing ; SMB = LXC `samba` ; pas de doublon sous `/tank/backups`
- ✅ `backup-usb` élargi : run 24 oct. snapshot `<snapshot>` (dossiers live + `/tank/backups`)
- ✅ SMB LAN : LXC `samba` CT 102, `\\<ip-samba>`, cinq partages, user `utilisateur` — (document privé)
- ✅ Permissions : lecture + écriture depuis Windows (24 oct.)
- ✅ Première restauration de fichiers perso : `<snapshot>` → `/tmp`, SHA-256 identique (24 oct.)

---

# Phase 2 — Sauvegarde Android

**Close le 25 oct.** Photos : la copie sur `tank` et le snapshot suffisent, pas de restore du dossier. SMS : pas restaurés, pas de besoin pour l'instant ; le JSON reste dans `<snapshot>`.

**Objectif** : procédure reproductible pour changer de téléphone ou récupérer après une perte.

**Dépendances** : phase 0 (protection) et phase 1 (stockage cible). Les deux sont assez solides (24 oct.).

Travail : (document privé).

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

## Jalons

Périmètre de ce téléphone (24 oct.) : photos, contacts, SMS si possible. Calendrier et secrets : hors périmètre. La procédure vise LineageOS **et** GrapheneOS. (document privé).

- ✅ Inventaire (LineageOS 22.2 / Android 15, pas de sauvegarde constructeur)
- ✅ Liste des apps : déclarée. Obtainium si l'éditeur publie une source. LineageOS : Aurora + microG. Ce GrapheneOS : Play Services + Aurora, compte Google à part. Liste Play installée le 25 oct. une application : Play Store, les autres : Aurora. Mullvad en place. Export JSON Obtainium sur `tank` (nom non relevé), dans le snapshot `<snapshot>`.
- ✅ Photos : pellicule déclarée dans `/tank/images/telephone` (24 oct., via le PC). SHA-256 sur une photo. Snapshots `<snapshot>` et `<snapshot>`. Restore du dossier non exigé (25 oct.).
- ✅ Contacts : `contacts_20261024_151331.vcf`, 52 fiches identiques au carnet d'origine (24 oct.). Restore `<snapshot>` → `/tmp`, SHA-256 identique, live conservé. Import sur le nouveau téléphone le 24 oct., sans Fossify Contacts, déclaré complet.
- ✅ SMS : Fossify Messages, `Messages_20261024_151932.json`, un message reconnu sur `pve` (24 oct.). Appli pas figée. Dans `<snapshot>`. Pas restauré : pas de besoin (25 oct.). Le fichier reste.
- ✅ Signal : `/tank/documents/telephone/SignalBackups` (24 oct. 20:47). Restore sur le nouveau téléphone, 24 oct. Clé hors dossier. Dans le snapshot `<snapshot>` (25 oct.).
- ✅ WhatsApp : transfert de téléphone à téléphone via l'appli (24 oct.). Pas de fichier sur `tank`.

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

# Phase 4 — Mediatheques

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
| Navidrome | Lecteur musique, en service (2 nov.) |

Ordre utile : datasets et droits → Jellyfin (fichiers déjà là) → qBittorrent isolé → Prowlarr puis Sonarr / Radarr → Bazarr / Recyclarr → Lidarr → Navidrome → page de liens des interfaces *arr → backups des **configs**.

Les médias récupérables n'ont pas le même besoin de backup que les photos ou documents irremplaçables. Les configurations et métadonnées, si.

**Critère** : un fichier de test suit le parcours prévu ; les configs se restaurent.

Travail : [Mediatheques.md](Mediatheques.md).

## Jalons

Layout retenu : **un** dataset `tank/mediatheques` (films, séries, sons, téléchargements dedans — liens physiques Sonarr/Radarr). Pas dans `backup-usb`. Jellyfin : **LXC** CT 103, en service le 28 oct. qBittorrent : **LXC** CT 104, `<ip-qbittorrent>`, Proton VPN pour le seul compte du client (29 oct., Mullvad gardé dans `wg0.conf.mullvad`). Prowlarr, Sonarr, Radarr et Bazarr : **un** LXC CT 105, `<ip-servarr>`. Prowlarr **2.7.0.5723**, Sonarr **4.0.20.3014**, Radarr **6.4.4.10685** en service le 28 oct. Bazarr **v1.6.2** (6767) en service le 29 oct., profil `français`, pas de fournisseur. Knaben : test Prowlarr réussi le 29 oct., visible dans Sonarr et Radarr. Grab *Preacher* S03E01 sans seed. EZTV non gardé (`eztvx.to` introuvable). Recyclarr **v8.8.1** sur le CT 105 (1er nov.) : profils MULTi.VO créés, non assignés. Lidarr **3.1.6.5079** sur le même CT (1er nov.), port 8686, `sons/` importé sans recherche. Navidrome retenu le 1er nov. (lecteur téléphone). Hébergement tranché le 2 nov. : LXC 106, `<ip-navidrome>`, lecture seule, paquet **0.64.2**, port 4533. Public : `https://navidrome.labo.example`, sans Access. Symfonium **15.1.0** : lecture validée le 2 nov. Tempus pas testé. Interfaces *arr visées hors LAN : un nom chacune, Access devant, puis une page de liens. Pas joué. qBittorrent hors de ce pas.

- ✅ Dataset `tank/mediatheques` + groupe `media` (GID 987) + dossiers `2770` (27 oct.) — [Mediatheques.md](Mediatheques.md)
- ✅ Copie PC sur `tank/mediatheques` : 2,1 Tio (28 oct.). Détail par dossier non relevé. Originaux PC conservés.
- ✅ Jellyfin LXC 103 (`<ip-jellyfin>`), 12.4+deb13. Scan terminé, un film lu (28 oct.) — [Mediatheques.md](Mediatheques.md#jellyfin--décision-28-oct)
- ✅ qBittorrent : LXC 104, `.70`, Mullvad. Fichier de test en `0660` `media` (28 oct.) — [Mediatheques.md](Mediatheques.md#qbittorrent--décision-28-oct)
- ✅ Prowlarr 2.7.0.5723, CT 105, compte `utilisateur`, Forms activé (28 oct.) — [Mediatheques.md](Mediatheques.md#prowlarr--décision-28-oct)
- ✅ Sonarr 4.0.20.3014 : *Cold Case* reconnue, `/mnt/mediatheques/series/Cold Case`, saisons 4 à 7 complètes (28 oct.) — [Mediatheques.md](Mediatheques.md)
- ✅ Radarr 6.4.4.10685 : *American History X* **Downloaded**, `/mnt/mediatheques/films/American History X (1998)`, 1,9 Gio (28 oct.) — [Mediatheques.md](Mediatheques.md)
- ✅ Bazarr v1.6.2, CT 105, port 6767. Sonarr et Radarr testés. Profil `français`. Pas de fournisseur (29 oct.) — [Mediatheques.md](Mediatheques.md#bazarr--décision-28-oct)
- ✅ Indexeur Knaben : test Prowlarr réussi, visible dans Sonarr et Radarr (29 oct.). EZTV retiré : `eztvx.to` ne se résout pas. — [Mediatheques.md](Mediatheques.md#indexeur--knaben-29-oct)
- ✅ Proton VPN sur le CT 104 (29 oct.) : tunnel `FR#506`, `proton-port`, coupure `000`, port `64509` joignable. Clé Mullvad gardée dans `wg0.conf.mullvad`. — [Mediatheques.md](Mediatheques.md#proton--décision-29-oct)
- ✅ Recyclarr v8.8.1, CT 105, binaire (1er nov.). Profil MULTi.VO créé dans Sonarr et Radarr, non assigné. **Any** inchangé — [Mediatheques.md](Mediatheques.md#recyclarr--décision-29-oct)
- ✅ Lidarr 3.1.6.5079, CT 105, port 8686 (1er nov.). `sons/` importé, client qBittorrent et Prowlarr testés. Pas de recherche — [Mediatheques.md](Mediatheques.md#lidarr--décision-1er-nov)
- ✅ Navidrome en service (2 nov.), CT 106 `.90:4533` et `https://navidrome.labo.example`, sans Access. Symfonium **15.1.0** : lecture validée. Tempus pas testé — [Mediatheques.md](Mediatheques.md#navidrome--décision-2-nov)
- ⬜ Interfaces *arr hors LAN : cinq noms, Access, page de liens. Pas joué. qBittorrent hors de ce pas — [Cloudflare.md](Cloudflare.md#visé-1er-nov-pas-joué)
- ⬜ Configs sauvegardées, restauration testée

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
- Interfaces *arr et Navidrome : choix écrit le 1er nov., pas joué. [Mediatheques.md](Mediatheques.md#navidrome-et-portail--choix-1er-nov).
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
| Stockage personnel | SMB visé (LAN) ; Nextcloud / Syncthing **pas pris** | Phase 1 (partage encore à poser) |
| Sauvegarde Android | Outils par catégorie | Phase 2 |
| Hébergement d'un service | VM, LXC, Docker, K3s | Avant **chaque** service |
| Musique | Navidrome en service (2 nov.), y compris `navidrome.labo.example`. Symfonium **15.1.0** validé. Tempus pas testé | Phase 4 |
| Accès distant | Tunnel en place. *arr : Access. Navidrome : sans Access. Page de liens visée, pas jouée. WireGuard pas décidé | Phase 6 |
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
