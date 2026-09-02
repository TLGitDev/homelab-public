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

- Mettre en œuvre les sauvegardes et tester une restauration.
- Créer le pool de données (miroir IronWolf).

---

# Changelog

| Date | Évolution |
|------|-----------|
| 2026-08-27 | Sprint 1 : plateforme matérielle validée. Sprint 2 : Proxmox installé. |
| 2026-08-28 | Sprint 3 : dépôts, DNS, NTP, premières mises à jour. Architecture.md créé. |
| 2026-08-29 | Sprint 4 : étude ZFS (théorie). |
| 2026-08-31 | Sprints 5–6 : LXC, Cloudflare Tunnel, Access, MFA. |
| 2026-09-02 | Sprints 7–8 : stratégie de sauvegarde, incident IP, réinstall ZFS. |