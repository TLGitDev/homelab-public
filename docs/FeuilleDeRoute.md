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
Phase 0   Fiabiliser l'existant
Phase 1   Organiser les données personnelles
Phase 2   Sauvegarde Android
Phase 3   Forge Git et CI/CD
Phase 4   Mediatheques

Phase 5   Une panne de sauvegarde se voit
Phase 6   Forge et GitOps tenables
Phase 7   Un LXC se reconstruit
    ├── Phase 8   Le même moule, un LXC à la fois
    ├── Phase 9   Accès distant et exploitation
    └── Phase 10  Dépôt public allégé
            └── Phase 11  Site CV public
```

Les phases 0 à 4 sont jouées. La suite se lit dans l'ordre des numéros.

On ne modifie pas la forge ni un conteneur tant que la phase 5 n'est pas jouée. La phase 6 commence par sortir l'archive Gitea de `k3s-01`. Puis : contrôle des manifestes, `ROOT_URL`, retrait de l'essai. La phase 7 s'enregistre une fois ce `ROOT_URL` posé.

Les phases 8, 9 et 10 partent de la phase 7. La 8 et la 9 avancent ensemble. La 10 publie dès la phase 7, puis se remet à jour à chaque LXC de la phase 8. La phase 11 s'y branche. La page agent reste hors de cette suite tant qu'elle n'existe pas.

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

**Objectif** : Gitea, édition libre, et un workflow professionnel. Un push lance le build, les tests, puis un déploiement repris par Argo CD.

**Dépendance** : phase 0. La comparaison peut commencer plus tôt. La forge retenue doit être sauvegardée **avant** d'y mettre des éléments essentiels.

On **garde** K3s et Argo CD pour ce qui y tourne déjà. On ne bascule pas automatiquement tout le futur sur Kubernetes : le mode de déploiement se choisit par besoin (VM, LXC, conteneurs, K3s).

## 3.1 Comparer Gitea et Forgejo

Décision **prise le 3 nov.** : Gitea, édition libre. Le but est un workflow professionnel, sur le modèle des gestes GitHub. Pod en service sur le LAN. [Forge.md](Forge.md#décision).

- [x] Maintenance et gouvernance (3 nov.) — [Forge.md](Forge.md#maintenance-et-gouvernance)
- [x] Fonctions Git (issues, PR, releases, registre, intégrations) (3 nov.) — [Forge.md](Forge.md#fonctions-git)
- [x] CI/CD (workflows, runners, secrets, déclencheurs) (3 nov.) — [Forge.md](Forge.md#ci)
- [x] Déploiement (hébergement, MAJ, migration, sauvegarde) (3 nov.) — [Forge.md](Forge.md#déploiement)
- [x] Écosystème (doc, plugins, communauté) (3 nov.) — [Forge.md](Forge.md#écosystème)
- [x] Coût opérationnel dans ce homelab (3 nov.) — [Forge.md](Forge.md#coût-opérationnel)

6 / 6 examinés. Gitea retenu. Pod en service sur le LAN.

## Jalons Gitea

Le choix est joué. Le pod est en service. La sauvegarde du dossier a été lue. La demande de fusion d'essai est fusionnée. Le miroir d'essai est joué. Le runner est en ligne. Le workflow d'essai est vert. Le déploiement d'essai a été synchronisé puis ramené en arrière. La forge est publiée derrière Access. L'essai `admin/homelab` est retiré. La forge et le runner ont été restaurés une fois. Décision du 4 nov. : Argo CD lit GitHub, et `homelab` n'a pas de copie de travail sur Gitea. Les jalons Gitea sont joués. [Forge.md](Forge.md#décision).

**Critère** : un changement versionné passe les tests et se déploie, avec un retour arrière.

- ✅ Gitea, édition libre (3 nov.). Enterprise non retenu. Gestes visés : dépôt, demande de fusion, branche protégée, Actions, runner à part, Argo CD.
- ✅ RAM libre de `k3s-01` (3 nov.) : 7,5 Gio au total, 5,5 Gio disponibles, 4 cœurs, échange 3,3 Gio inutilisé. Disque système 51 Go libres. Vaultwarden 14 Mio, Argo CD jusqu'à 206 Mio.
- ✅ Pod sur `k3s-01` (3 nov.), une réplique, SQLite. Zvol `tank/vmdata/vm-101-gitea-data`, ni le disque système ni le zvol Vaultwarden. Manifests dans `git@github.com:TLGitDev/homelab.git`. Compte `admin`. Aucun dépôt.
- ✅ Sauvegarde du dossier de données (3 nov.), Gitea arrêté. Archive `gitea-2026-11-03_180902.tar` sur `k3s-01`, SHA-256 `<empreinte-vérifiée>`. Relue ailleurs : base `ok`, `SECRET_KEY` de 64 caractères, compte `admin`, zéro dépôt. Pas encore copiée sur `pve`.
- ✅ Dépôt d'essai `admin/homelab` poussé depuis le PC (3 nov.). `master` protégée : le push direct est refusé. Demande de fusion n° 1 fusionnée, commit `ad9faf2`. Argo lit toujours GitHub.
- ✅ Miroir d'essai (4 nov.) : `admin/essai-miroir` vers `TLGitDev/essai-miroir`, déjà créé et vide. Même commit `e2e0eb6a` des deux côtés. Pas `homelab`. Commits seulement. Le jeton reste dans le coffre.
- ✅ Runner hors de `k3s-01` (4 nov.). LXC 107 `runner`, `<ip-runner>`, non privilégié, sans montage de `tank` ni droit sur le cluster. `gitea-runner` `v5.2.0`, étiquette `host`, service `active`. Page : id 1, global, Idle. `.runner` en 600. [Forge.md](Forge.md#décision)
- ✅ Workflow (4 nov.) : push sur `admin/essai-miroir`, pas sur `homelab`. Actions du dépôt activées. CI n° 1, commit `0813dcc290`, branche `main`, vert en 2 s. Étiquette `host`, seul runner qui la porte. [Forge.md](Forge.md#décision)
- ✅ Déploiement repris par Argo CD depuis GitHub, avec un retour arrière (4 nov.). Application `essai-deploiement`, sync manuel. Commit `a6c4965` : ConfigMap `version` `1`. Commit `31fcdee` : `2`, vérifié dans le cluster. Rollback Argo vers `a6c4965` : le cluster relit `1`, statut `OutOfSync`. Git reste sur `31fcdee`. Pas le coffre, pas la forge.
- ✅ Depuis l'extérieur (4 nov.) : `https://gitea.labo.example`, tunnel `homelab`, origine `http://<ip-k3s-01>:3000`, Access devant. Page de connexion Gitea vue. Essai `admin/homelab` retiré. Remote local `gitea` retiré. `ROOT_URL` reste l'adresse du LAN. `admin/essai-miroir` reste. [Cloudflare.md](Cloudflare.md)
- ✅ Restauration de la forge et du runner, jouée une fois (4 nov.). Forge : `gitea-2026-11-04_150155.tar`, mode 600, propriétaire `utilisateur`, SHA-256 `<empreinte-vérifiée>`. Ouverte à côté, puis le dossier effacé. `integrity ok`, un dépôt `admin/essai-miroir`, `SECRET_KEY` 64, `INTERNAL_TOKEN` 105. Pod revenu `1/1`, disque en service intact. Pas l'archive du 3 nov. Runner : copie `/var/backups/gitea-runner-2026-11-04.tar`, mode 600. Fichier `.runner` retiré puis remis, identique. Service `active`, `declare successfully`, `v5.2.0`, libellés `[host]`. Pas un second enregistrement.

## Page agent (plus tard)

Idée du 3 nov., à mettre en place une fois la forge prête. Pas un jalon de la phase 3.

Un pod sur `k3s-01` avec le programme `agent`. Une page maison : conversation, et les diffs plus lisibles qu'en terminal. Le téléphone ouvre cette page. Dehors, Access devant. Le nom n'est pas choisi.

Le pod ne voit que son volume. Pas le disque de la machine, pas de droit sur le cluster. La clé du compte Cursor reste dans le pod. Le modèle tourne chez Cursor.

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

Ordre utile : datasets et droits → Jellyfin (fichiers déjà là) → qBittorrent isolé → Prowlarr puis Sonarr / Radarr → Bazarr / Recyclarr → Lidarr → Navidrome → backups des **configs**.

Les médias récupérables n'ont pas le même besoin de backup que les photos ou documents irremplaçables. Les configurations et métadonnées, si.

**Critère** : un fichier de test suit le parcours prévu ; les configs se restaurent.

Travail : [Mediatheques.md](Mediatheques.md).

## Jalons

Layout retenu : **un** dataset `tank/mediatheques` (films, séries, sons, téléchargements dedans — liens physiques Sonarr/Radarr). Pas dans `backup-usb`. Jellyfin : **LXC** CT 103, en service le 28 oct. qBittorrent : **LXC** CT 104, `<ip-qbittorrent>`, Proton VPN pour le seul compte du client (29 oct., Mullvad gardé dans `wg0.conf.mullvad`). Prowlarr, Sonarr, Radarr et Bazarr : **un** LXC CT 105, `<ip-servarr>`. Prowlarr **2.7.0.5723**, Sonarr **4.0.20.3014**, Radarr **6.4.4.10685** en service le 28 oct. Bazarr **v1.6.2** (6767) en service le 29 oct., profil `français`, pas de fournisseur. Knaben : test Prowlarr réussi le 29 oct., visible dans Sonarr et Radarr. Grab *Preacher* S03E01 sans seed. EZTV non gardé (`eztvx.to` introuvable). Recyclarr **v8.8.1** sur le CT 105 (1er nov.) : profils MULTi.VO créés, non assignés. Lidarr **3.1.6.5079** sur le même CT (1er nov.), port 8686, `sons/` importé sans recherche. Navidrome retenu le 1er nov. (lecteur téléphone). Hébergement tranché le 2 nov. : LXC 106, `<ip-navidrome>`, lecture seule, paquet **0.64.2**, port 4533. Public : `https://navidrome.labo.example`, sans Access. Symfonium **15.1.0** : lecture validée le 2 nov. Tempus pas testé. Interfaces *arr hors LAN (2 nov.) : un nom chacune, Access devant, login vérifié. Page de liens abandonnée. qBittorrent hors de ce pas.

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
- ✅ Interfaces *arr hors LAN (2 nov.) : cinq noms, Access, login vérifié. Page de liens abandonnée. qBittorrent hors de ce pas — [Mediatheques.md](Mediatheques.md#navidrome-et-portail--choix-1er-nov)
- ✅ Configs médiathèques (2 nov.) : `/tank/backups/mediatheques`, restauration lue (`ok`), USB `<snapshot>` — [Sauvegardes.md](Sauvegardes.md#configs-médiathèques-2-nov)

---

# Phase 5 — Une panne de sauvegarde se voit

**Objectif** : savoir, sans ouvrir de session, qu'une sauvegarde n'a pas tourné, qu'un pool n'est plus sain, ou qu'un disque se remplit.

**Dépendance** : les jobs déjà en place (phase 0). Pas une stack de tableaux : un canal.

Le canal se choisit au début. Contrainte : le message arrive sans SSH. Pistes : ntfy, courriel, healthchecks. Une seule.

Ce que le canal couvre :

- échec du timer d'archive Vaultwarden ;
- échec du timer de snapshots zvol ;
- dernière copie USB plus vieille que le seuil écrit ;
- `tank` autre que `ONLINE`, ou scrub en erreur ;
- espace sous un seuil écrit.

La rétention Restic, encore ouverte en phase 0, se ferme ici : durée choisie, appliquée, notée dans [Sauvegardes.md](Sauvegardes.md). Le seuil d'ancienneté USB s'aligne sur cette durée.

## Jalons

- ⬜ Canal choisi et noté
- ⬜ Rétention Restic appliquée — [Sauvegardes.md](Sauvegardes.md)
- ⬜ Les cinq contrôles ci-dessus branchés sur ce canal
- ⬜ Scrub de `tank` planifié ; un état mauvais passe par le même canal
- ⬜ Essai : un job fait échouer exprès, le message arrive, le job d'essai est retiré

**Critère** : un échec volontaire a prévenu, sans qu'il ait fallu aller voir le timer.

---

# Phase 6 — Forge et GitOps tenables

**Objectif** : la forge se restaure depuis une copie qui n'est pas sur son nœud, et un manifeste cassé se voit avant Argo CD.

**Dépendance** : phase 5 jouée. La forge elle-même est en place depuis la phase 3.

Décisions du 4 nov., pour cette phase :

- Argo CD continue de lire GitHub. `homelab` ne gagne pas de copie de travail sur Gitea.
- Le contrôle des manifestes tourne sur ce dépôt GitHub. Il ne déploie rien.
- `essai-deploiement` sort du cluster et du dépôt une fois ce contrôle vert. Le rollback du 4 nov. reste écrit en phase 3.

## Jalons

Dans cet ordre.

- ⬜ Archive utile de Gitea recopiée hors de `k3s-01` (sur `pve`, puis dans le périmètre USB). Empreinte vérifiée sur la copie. L'archive qui reste seulement sur le disque de `k3s-01` n'est plus celle qu'on citerait. Cette copie entre dans ce que la phase 5 surveille.
- ⬜ Contrôle GitHub : YAML lu, manifestes confrontés au schéma Kubernetes du K3s en place. L'arbre courant est vert.
- ⬜ Un manifeste volontairement invalide rend le contrôle rouge, puis il est retiré.
- ⬜ `ROOT_URL` = `https://gitea.labo.example`. Connexion via Access vérifiée. L'adresse de clone affichée est le nom public. L'accès LAN répond encore.
- ⬜ `essai-deploiement` retiré du cluster et du dépôt. Argo ne le suit plus. Phase 3 garde le récit du rollback.

**Critère** : la forge se restaure depuis une copie qui n'est pas sur `k3s-01` ; le dépôt que lit Argo CD refuse un manifeste cassé ; il ne reste pas d'application d'essai `OutOfSync`.

---

# Phase 7 — Un LXC se reconstruit

**Objectif** : à partir du modèle Debian déjà sur `pve`, une commande refait le runner. Une deuxième passe ne change rien.

**Dépendance** : phase 6 jouée (`ROOT_URL` posé, archive hors du nœud). Le runner actuel, CT 107, sert de référence.

Décision du 4 nov. : Ansible, lancé depuis le PC. Pas un second outil pour un seul conteneur. Le playbook ne tourne pas sur le runner : il n'a pas à pouvoir recréer l'hyperviseur. Jeton d'API Proxmox et jeton d'enregistrement Gitea hors du dépôt, fichier ignoré par Git.

Deux rôles. Le premier parle à Proxmox : CT non privilégié, `nesting`, 2 Gio, 2 cœurs, 16 Go, adresse, démarrage automatique, aucun montage de `tank`. Le second parle dedans : compte `gitea-runner`, binaire `v5.2.0` vérifié par empreinte, unité systemd, config en `600`. L'enregistrement auprès de Gitea est une tâche à part. Git ne stocke pas le fichier `.runner`.

La preuve se fait sur un CT d'essai (108, autre adresse), pas en détruisant 107. 107 ne part que lorsque 108 a pris un workflow vert.

## Jalons

- ⬜ Rôles et playbook dans `infrastructure/ansible/`. Secrets absents du dépôt.
- ⬜ ADR : les LXC d'infra se décrivent en Ansible ; les applications déjà en manifestes restent dans Argo CD ; Proxmox lui-même reste un mode opératoire.
- ⬜ CT 108 créé par le playbook, runner enregistré, CI d'essai verte
- ⬜ Deuxième passe : aucun changement
- ⬜ 107 arrêté seulement après ça, ou 108 retiré et le récit gardé sur 107 encore en service. Un des deux, écrit.

**Critère** : le runner d'essai existe parce que le playbook l'a créé, et le relancer est sans effet.

Les phases 8 et 9 partent d'ici, ensemble. La phase 10 publie cette même base, puis suit la phase 8.

---

# Phase 8 — Le même moule, un LXC à la fois

**Objectif** : chaque LXC encore posé à la main suit le moule de la phase 7. Un seul à la fois.

**Dépendance** : phase 7 jouée. Avance en même temps que la phase 9.

Même critère à chaque fois : CT d'essai d'abord, commande unique, deuxième passe sans changement, secrets hors de Git. Le CT en service ne bouge qu'après l'essai.

Ordre, du plus simple au plus risqué :

| Ordre | LXC | Pourquoi dans cet ordre |
|-------|-----|-------------------------|
| 1 | Navidrome, CT 106 | Lecture seule, peu d'état |
| 2 | Jellyfin, CT 103 | Lecture seule sur les médias |
| 3 | Samba, CT 102 | `smb.conf` est déjà dans Git ; les montages et les droits sont le sujet |
| 4 | `servarr`, CT 105 | Plusieurs applications, un conteneur |
| 5 | qBittorrent, CT 104 | VPN, clés hors de Git |
| 6 | Cloudflare, CT 100 | En dernier : un échec coupe l'accès distant |

## Jalons

- ⬜ Navidrome
- ⬜ Jellyfin
- ⬜ Samba
- ⬜ `servarr`
- ⬜ qBittorrent
- ⬜ Cloudflare

**Critère** : la liste ci-dessus est cochée, chaque fois après un CT d'essai. La phase 10 est remise à jour à chaque ligne cochée.

---

# Phase 9 — Accès distant et exploitation

**Objectif** : plus simple à administrer, plus sûr au quotidien.

**Dépendance** : phase 7 jouée. Avance en même temps que la phase 8. Les alertes de sauvegarde sont déjà la phase 5.

- Rôles de Traefik, du tunnel Cloudflare, des accès LAN. [Cloudflare.md](Cloudflare.md), [ArgoCD.md](ArgoCD.md).
- Interfaces *arr : cinq noms en service, Access (2 nov.). Page de liens abandonnée. Navidrome en service, sans Access. [Mediatheques.md](Mediatheques.md#navidrome-et-portail--choix-1er-nov).
- Étudier WireGuard pour l'accès privé distant (**pas décidé**).
- Séparer services publics et interfaces d'admin.
- Mises à jour, redémarrages.
- Comptes, permissions, secrets, certificats, reprise : documentés. La reprise s'écrit sur un service qu'on sait reconstruire.

**Critère** : l'admin reste privé ; les routines sont écrites.

---

# Phase 10 — Dépôt public allégé

**Objectif** : une copie publique de ce dépôt, sur GitHub, qui montre le travail (décisions, manifestes, scripts, journal) sans donner la carte du réseau ni un secret.

**Dépendance** : phase 7 jouée. Pas besoin d'attendre la fin des phases 8 et 9. La copie se remet à jour à chaque LXC de la phase 8.

Décision du 4 nov. Ce dépôt-ci reste privé et reste la seule source. La copie publique ne s'édite pas à la main : une projection, rejouée depuis le PC, produit l'arbre puis le pousse. Le récit est sur le site (phase 11), qui lie cette copie.

La projection garde le plus possible. Elle remplace, plutôt que de supprimer des pages entières :

| Sort | Reste, récrit |
|------|----------------|
| Jetons, mots de passe, clés, SealedSecrets | Le manifeste, sans l'objet secret |
| Adresses LAN, plan d'adressage, origines et UUID de tunnel | Le nom du rôle (`pve`, `k3s-01`, `samba`…) |
| Noms DNS du labo | Un nom d'exemple. Coller le vrai nom à l'architecture donne la carte ; ces noms sont déjà résolvables |
| Chemins d'archives, empreintes de sauvegarde, comptes | Le fait qu'une archive a été relue et qu'une empreinte a été vérifiée |

`docs/Competences.md` est relu avant la publication : une ligne n'est publique que si un jalon a été joué. Les cases phase 0 encore ouvertes restent ouvertes dans la copie, elles aussi.

## Jalons

- ⬜ Règle ci-dessus écrite à côté du script, avec un exemple avant / après
- ⬜ Projection rejouable. Deuxième passe : la copie publique ne change que si le labo a changé
- ⬜ Relecture de l'arbre produit : plus d'adresse LAN, plus de secret, plus de SealedSecret, plus de nom DNS du labo
- ⬜ `docs/Competences.md` relu après les phases 5 à 7
- ⬜ Dépôt GitHub public créé et alimenté par la projection

**Critère** : un lecteur du dépôt public suit les ADR, les manifestes et le journal ; il n'en tire ni une adresse privée, ni un secret, ni le nom DNS qui joint le service.

---

# Phase 11 — Site CV public

**Objectif** : profil, projets, homelab. Le homelab y est raconté à partir du dépôt public, pas à partir du labo.

**Dépendance** : phase 3 pour le pipeline. Phase 10 pour le contenu homelab.

- Dépôt versionné, contenus publics seulement.
- Génération + validation automatiques, puis déploiement. Exposition minimale, HTTPS.
- Trois récits, chacun avec sa limite :
  1. Une donnée survit à la machine. Miroir, copie externe, restauration jouée. Limite : le système est sur un seul NVMe ; le rollback snapshot et la reprise réelle du volume de prod restent écrits, non joués.
  2. Un changement a un chemin et un retour arrière. Branche protégée, secret chiffré, runner hors du nœud du coffre, Argo CD. Limite : les manifestes se reconstruisent par GitOps ; les LXC suivent le moule de la phase 7, un à la fois.
  3. L'accès distant est refusé par défaut. Pas de redirection de port, tunnel, Access devant l'admin. Limite : le coffre et le lecteur musique s'authentifient dans l'application.
- Une colonne homelab → cloud : hyperviseur, isolation, stockage et instantanés, accès sans port ouvert, GitOps, secrets versionnés, copie externe.
- Lien vers le dépôt public. Aucun lien vers une interface d'admin, ni vers le dépôt privé.

## Jalons

- ⬜ Les trois récits, leurs limites, et la colonne cloud sont sur le site
- ⬜ Le site pointe le dépôt public de la phase 10, et seulement celui-là
- ⬜ Première version en ligne, HTTPS
- ⬜ Un commit valide déclenche le déploiement
- ⬜ Relecture : rien n'a été copié à la main depuis le labo

**Critère** : le site raconte le homelab, un commit le redéploie, et aucune donnée du labo privé n'y figure.

---


# Décisions encore ouvertes

| Sujet | Décision | Quand |
|-------|----------|-------|
| Forge Git | Gitea, édition libre (3 nov.). Argo CD lit GitHub (4 nov.). `homelab` sans copie de travail sur Gitea. Contrôle des manifestes sur ce dépôt GitHub, pas sur le runner (4 nov.). `essai-deploiement` à retirer une fois ce contrôle vert. `ROOT_URL` à aligner sur `gitea.labo.example`. Archive utile encore à sortir de `k3s-01`. | Phase 6 |
| Stockage personnel | SMB visé (LAN) ; Nextcloud / Syncthing **pas pris** | Phase 1 (partage encore à poser) |
| Sauvegarde Android | Outils par catégorie | Phase 2 |
| Hébergement d'un service | VM, LXC, Docker, K3s | Avant **chaque** service |
| Musique | Navidrome en service (2 nov.), y compris `navidrome.labo.example`. Symfonium **15.1.0** validé. Tempus pas testé | Phase 4 |
| Accès distant | Tunnel en place. Cinq noms *arr avec Access (2 nov.). Navidrome sans Access. Page de liens abandonnée. WireGuard pas décidé | Phase 9 |
| Supervision | Un canal d'alerte, sans tableau. Pistes : ntfy, courriel, healthchecks. Une seule. WireGuard et les routines restent en phase 9. | Phase 5 |
| Reconstruction des LXC | Ansible depuis le PC, runner d'abord (4 nov.). Les autres LXC suivent le même moule, un par un. Jeton Proxmox et jeton d'enregistrement hors de Git. | Phases 7 et 8 |
| Dépôt montré | Le labo reste privé et seule source (4 nov.). Une projection rejouable alimente un second dépôt GitHub, public. Les adresses LAN deviennent des rôles, les noms DNS du labo deviennent un exemple, les secrets sortent. Le site CV pointe cette copie. | Phases 10 et 11 |

Pas d'ADR tant que le choix n'est pas tranché.

---

# Hors phases (plus tard)

Idées **gardées**, pas planifiées :

- Home Assistant
- Paperless
- Immich
- Page agent sur le téléphone, une fois la forge prête — [plus tard](#page-agent-plus-tard). Absente du récit d'entretien tant que le pod n'existe pas.

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
8. Un LXC d'infra devient reproductible sur le moule déjà prouvé, un à la fois.
