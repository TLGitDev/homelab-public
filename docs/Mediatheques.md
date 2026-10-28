# Mediatheques

> Phase 4 : bibliothèque sur `tank`, avant les applis.
>
> Cible : [FeuilleDeRoute.md](FeuilleDeRoute.md#phase-4--mediatheques). Perso (autre politique) : (document privé). Protection : [Sauvegardes.md](Sauvegardes.md). Stockage : [Stockage.md](Stockage.md).

---

# Objectif

Un volume pour les fichiers à consommer (`Films`, `Séries`, `Sons` du PC), séparé des dossiers perso. Les applis viennent après : Jellyfin d'abord, une fois des fichiers en place.

**As-built 2026-10-28.** Dataset sur `pve`, groupe `media` = GID **987**, **2,1 Tio**. `utilisateur` n'est pas dans ce groupe. Répartition films / séries / sons non affichée par le `du` lancé (voir plus bas). Pas dans `backup-usb`.

---

# Layout

Un seul dataset : `tank/mediatheques`.

Même politique pour films, séries, sons et téléchargements : récupérable, **pas** dans `backup-usb`. Un dataset parce que la politique n'est pas celle de `tank/musique` ni `tank/videos`. Pas un dataset par dossier Windows.

Les téléchargements sont **dans** ce dataset, pas à côté. Sonarr / Radarr font un lien physique (hardlink) entre le fichier terminé et la bibliothèque. Un lien physique ne traverse pas deux datasets. Deux datasets = deux copies, ou une copie au lieu d'un lien.

```
tank/mediatheques
├── films
├── series
├── sons
└── telechargements
    ├── incomplets
    └── complets
```

| Dossier PC | Sur `tank` |
|------------|------------|
| `Mediatheques/Films` | `/tank/mediatheques/films` |
| `Mediatheques/Séries` | `/tank/mediatheques/series` |
| `Mediatheques/Sons` | `/tank/mediatheques/sons` |

`tank/musique` et `tank/videos` ne bougent pas. Ce ne sont pas les médiathèques.

Groupe hôte `media`. Répertoires `2770`, `root:media` : le groupe écrit, les autres non. Les futurs comptes (Jellyfin, client torrent, *arr) rejoindront ce groupe. `utilisateur` / `perso` restent les dossiers perso.

`recordsize` : défaut ZFS (128K). On ne le change pas avant un besoin mesuré.

Pas de timer de snapshots sur ce dataset. Pas de quota tant que la taille copiée n'est pas connue. Pas d'entrée dans `SOURCE_DIRS` de `backup-usb`. Les configs d'applis se sauvegarderont plus tard, à part.

Hébergement de Jellyfin : **LXC** (décision 28 oct., procédure plus bas, pas jouée). Les fichiers restent ici.

Partage SMB : **pas dans ce pas**. L'idmap du CT 102 ne mappe que `utilisateur` (999) et `perso` (988). Ajouter `media` oblige à réécrire cette map et à redémarrer Samba, qui sert déjà les cinq partages perso. La première copie se fait en root (SFTP), comme `tank/documents` le 23 oct.

---

# Sur `pve` (root)

Faire les blocs **dans l'ordre**. En cas d'erreur : coller la sortie. Ne pas improviser un `zfs destroy` ni un `rm` sur `/tank`.

## 0. Constat

```bash
zfs list -r -o name,used,avail,mountpoint tank
zfs get compression,mountpoint tank tank/documents
getent group media || true
getent group perso
id utilisateur
ls -ld /tank/mediatheques 2>/dev/null || true
```

`tank/mediatheques` ne doit pas exister. `media` non plus, sauf si le constat dit le contraire : dans ce cas, s'arrêter et coller `getent`.

## 1. Dataset, groupe, dossiers

```bash
zfs create tank/mediatheques
zfs set compression=on tank/mediatheques
getent group media >/dev/null || groupadd --system media
chgrp media /tank/mediatheques
chmod 2770 /tank/mediatheques
install -d -m 2770 -o root -g media \
  /tank/mediatheques/films \
  /tank/mediatheques/series \
  /tank/mediatheques/sons \
  /tank/mediatheques/telechargements/incomplets \
  /tank/mediatheques/telechargements/complets
```

## 2. Vérifier

```bash
zfs list -o name,used,avail,mountpoint tank/mediatheques
zfs get compression,mountpoint,recordsize tank/mediatheques
getent group media
ls -ld /tank/mediatheques \
  /tank/mediatheques/films \
  /tank/mediatheques/series \
  /tank/mediatheques/sons \
  /tank/mediatheques/telechargements \
  /tank/mediatheques/telechargements/incomplets \
  /tank/mediatheques/telechargements/complets
chmod 2770 /tank/mediatheques/telechargements
```

`install -d` applique `-m` au dernier dossier du chemin. `telechargements/` est un intermédiaire : il sort en `2755` (`drwxr-sr-x`, setgid hérité, pas d'écriture groupe). Le `chmod` l'aligne sur `2770`.

Attendu : compression `on`, mountpoint `/tank/mediatheques`, `drwxrws---` et groupe `media` partout. `backup-usb` inchangé (pas de nouveau chemin).

## As-built (27 oct. 10:14)

Constat avant création : `tank` 99,7 Gio utilisés, 7,04 Tio libres. Compression du pool déjà `on` (défaut). `media` absent. `perso` = 988, `utilisateur` = 999. Pas de `/tank/mediatheques`.

Après les commandes :

| Propriété | Valeur |
|-----------|--------|
| Dataset | `tank/mediatheques`, 96 Kio, mountpoint `/tank/mediatheques` |
| Compression | `on` (source `local` : `zfs set` explicite) |
| `recordsize` | 128K (défaut) |
| Groupe | `media:x:987:` |
| `films`, `series`, `sons`, `incomplets`, `complets`, racine | `drwxrws---` `root:media` |
| `telechargements` | `drwxrws---` `root:media` après `chmod 2770` (10:17 ; avant : `2755`) |

`zfs set compression=on` était redondant (le pool est déjà `on`) ; la propriété reste, source `local`. Rien ajouté à `backup-usb`. Aucun CT ne monte ce dataset.

Retour arrière, **seulement** si le dataset est vide et qu'aucun CT ne le monte : `zfs destroy tank/mediatheques`, puis `groupdel media` si le groupe ne sert plus. Pas tant qu'une copie est en cours.

---

# Copie depuis le PC

Originaux PC **conservés**. Ne pas poser les fichiers à la racine du dataset : chacun dans son dossier.

**WinSCP** : SFTP, user `root`, hôte `<ip-pve>`. Glisser le **contenu** de chaque dossier, pas le dossier lui-même (sinon `films/Films`).

| Local | Distant |
|-------|---------|
| `Films` | `/tank/mediatheques/films` |
| `Séries` | `/tank/mediatheques/series` |
| `Sons` | `/tank/mediatheques/sons` |

**PowerShell** (client OpenSSH), même recette que `tank/documents`. Le `*` copie le contenu dans le dossier déjà créé. Rien vers `telechargements/`.

```powershell
scp -r "F:\Mediatheques\Films\*" root@<ip-pve>:/tank/mediatheques/films/
scp -r "F:\Mediatheques\Series\*" root@<ip-pve>:/tank/mediatheques/series/
scp -r "F:\Mediatheques\Sons\*" root@<ip-pve>:/tank/mediatheques/sons/
```

Si le lecteur n'est pas `F:`, changer le chemin. Si `scp` est introuvable : Paramètres → Applications → Fonctionnalités facultatives → « Client OpenSSH ». Une copie interrompue ne reprend pas : relancer la même commande recopiera par-dessus.

Après la copie, sur `pve` (les fichiers déposés en root n'héritent pas tout seuls du groupe) :

```bash
chgrp -R media /tank/mediatheques
find /tank/mediatheques -type d -exec chmod 2770 {} +
find /tank/mediatheques -type f -exec chmod 0660 {} +
du -sh --max-depth=1 /tank/mediatheques
```

`du -sh /tank/mediatheques /tank/mediatheques/*` ne réaffiche pas les sous-dossiers : ils sont déjà comptés dans le parent. `--max-depth=1` les montre.

## As-built (28 oct.)

`chgrp -R media`, `chmod 2770` sur les dossiers, `chmod 0660` sur les fichiers : aucune erreur. `du` : **2,1 Tio** pour `/tank/mediatheques`. Le détail par dossier n'est pas sorti. Originaux PC conservés (copie, pas un déplacement). `telechargements/` n'était pas une source.

---

# Jellyfin — décision (28 oct.)

Jellyfin tourne dans un **LXC Debian** sur `pve`, en lecture sur `tank/mediatheques`. Pas dans K3s. Pas dans une VM. Les fichiers ne bougent pas.

Pourquoi un LXC :

- `tank/mediatheques` est un dataset de l'hôte. Un LXC le reçoit en bind mount, comme Samba reçoit les dossiers perso. Le processus lit les fichiers là où ils sont.
- `k3s-01` est une VM. Elle ne voit pas les datasets de l'hôte. L'y mettre demanderait un partage (NFS) ou une copie, pour des fichiers déjà sur la même machine. L'ADR-008 réserve NFS au partage, et `tank/vmdata` aux zvol : ni l'un ni l'autre n'est le bon rangement pour ces 2,1 Tio.
- Cette VM héberge déjà Vaultwarden. Un scan de bibliothèque ou un transcodage prendrait du CPU et de la RAM au coffre.
- L'iGPU du 5700G, s'il sert un jour, se monte dans le LXC. Le passer à la VM puis au Pod est un autre chantier. Ce pas-ci ne le fait pas : les clients lisent les fichiers tels quels.

Ce que ce LXC n'est pas :

- Pas une copie de la bibliothèque. Montage **lecture seule**.
- Pas un zvol, pas un dossier sous `tank/vmdata`.
- La config Jellyfin (`/var/lib/jellyfin`) vit sur le disque du CT (`rpool`). C'est elle qu'il faudra sauvegarder plus tard, pas les médias. Pas dans ce pas.
- Ce pas : LAN seulement, pas de route dans le tunnel. **Plus tard** : hostname public, Cloudflare Access devant, origine `http://<ip-jellyfin>:8096` (le LXC, pas Traefik). Même tunnel que Proxmox et Argo CD. Les applis Jellyfin (téléphone, TV) ne passent pas une page Access : ce détail se tranche à ce moment-là, pas maintenant.
- Pas de Docker dans le CT. Le paquet Debian officiel, pour voir le service et ses fichiers.

qBittorrent, Sonarr et Radarr ne sont pas dans ce pas. Quand ils viendront, ils devront voir ce même dataset (liens physiques). Le montage Jellyfin est en lecture seule : il ne écrit pas dans `telechargements/`.

Pas d'ADR : le critère général (VM, LXC, K3s selon le service) reste ouvert. Ici, un seul service est tranché.

---

# Jellyfin — procédure

**As-built 28 oct.** CT **103** `jellyfin`, `<ip-jellyfin>`, **running**. Paquet **12.4+deb13**, `/health` = `Healthy`. Compte `jellyfin` (UID 102) dans `media`. Scan terminé. Un film lu jusqu'au bout, sans incident. Lecture VO + sous-titres FR réglée. Règle `/etc/pve/firewall/103.fw` : pas confirmée. Le pare-feu datacenter reste éteint.

Faire les blocs **dans l'ordre**. En cas d'erreur : coller la sortie. Ne pas `zfs destroy`, ne pas `rm` sur `/tank/mediatheques`, ne pas passer le CT en privilégié.

## 0. Constat (sur `pve`, root)

```bash
pct list
qm list
ping -c 1 -W 1 <ip-jellyfin> || true
free -h
ls /var/lib/vz/template/cache/
getent group media
grep -E '^root:' /etc/subgid
pve-firewall status || true
```

Attendu : pas de CT 103, pas de VM 103, `.60` sans réponse, groupe `media` GID 987, template `debian-13-standard_13.1-2_amd64.tar.zst`. `free -h` : au moins 4 Gio disponibles. Sinon, coller et s'arrêter.

**Constat 28 oct.** CT 100 `cloudflare` et 102 `samba` en service. VM 101 `k3s-01`, 8 Gio, 64 Gio. Pas de 103. `.60` sans réponse. RAM disponible 20 Gio. Template Debian 13 présent. `media` = 987. `subgid` : `root:100000:65536` et `root:988:1` (pas encore `987`). Pare-feu Proxmox : `disabled/running` — la règle du CT s'écrira, elle ne filtre pas tant que le pare-feu du datacenter reste éteint. On ne l'allume pas dans ce pas.

## 1. Autoriser le GID hôte 987

Le CT non privilégié n'a le droit d'utiliser que les GID listés dans `/etc/subgid`. `987` n'est pas dans `100000:65536`. Une ligne, pas de doublon.

```bash
grep -q '^root:987:1$' /etc/subgid || echo 'root:987:1' >> /etc/subgid
grep -E '^root:' /etc/subgid
```

## 2. Créer le LXC (arrêté)

Même socle que Samba : `vmbr0`, `local-zfs`, non privilégié, Debian 13, `nesting=1`. Sans nesting, systemd 257 (Debian 13) prévient au `pct create`. 4 Gio de RAM, 2 cœurs, disque 16 Gio pour la config et les métadonnées. Démarrage avec l'hôte.

```bash
pct create 103 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname jellyfin \
  --memory 4096 \
  --swap 512 \
  --cores 2 \
  --rootfs local-zfs:16 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,ip=<ip-jellyfin>/24,gw=<ip-box> \
  --nameserver <ip-box> \
  --unprivileged 1 \
  --features nesting=1 \
  --ostype debian \
  --onboot 1 \
  --start 0
```

Bibliothèque en lecture seule :

```bash
pct set 103 -mp0 /tank/mediatheques,mp=/mnt/mediatheques,ro=1
```

**28 oct.** `subgid` a `root:987:1`. CT 103 créé, `mp0` en lecture seule, idmap collée. `nesting=1` ajouté après le `pct create` (systemd 257). `pct start` : **running**.

## 3. Idmap

Sans ça, le CT voit les fichiers en `nobody` et Jellyfin ne peut pas les lire (`0660`, groupe `media` seulement).

Dans `/etc/pve/lxc/103.conf`, les lignes `lxc.idmap` doivent être **exactement** celles-ci (remplacer un `g 0 100000 65536` s'il a été écrit) :

```
lxc.idmap: u 0 100000 65536
lxc.idmap: g 0 100000 1000
lxc.idmap: g 1000 987 1
lxc.idmap: g 1001 101001 64535
```

UID : plage par défaut (le compte Jellyfin possède sa config dans le CT). GID 1000 **dans** le CT = GID 987 **sur l'hôte** (`media`). Le reste des GID reste dans la plage non privilégiée.

```bash
grep idmap /etc/pve/lxc/103.conf
pct start 103
pct status 103
```

Si `newgidmap` / `not allowed` : la ligne `root:987:1` manque, ou les plages se chevauchent. Coller `pct start` et le `grep`. Ne pas continuer.

## 4. Groupe dans le CT

```bash
pct exec 103 -- bash -lc 'getent group media >/dev/null || groupadd --gid 1000 media'
pct exec 103 -- ls -ld /mnt/mediatheques
```

**28 oct.** `/mnt/mediatheques` s'affiche `nobody media`, mode `drwxrws---`. Le propriétaire `nobody` est normal : l'UID 0 de l'hôte n'est pas dans la map. Le groupe `media` prouve que le GID 987 est bien le GID 1000 du CT. `ls` des sous-dossiers en root du CT est refusé : ce root est l'UID hôte 100000, il n'est pas dans `media`, et le mode ne donne rien à « other ». Le test de lecture se fait avec le compte `jellyfin`, après `usermod -aG media`.

## 5. Paquet

Dépôt officiel Jellyfin, format DEB822, Debian 13 (`trixie`, `amd64`). Pas le script `install-debuntu.sh`. Pas `extrepo` en plus : une seule source.

```bash
pct exec 103 -- bash -lc 'cat /etc/os-release; dpkg --print-architecture'
```

Attendu : `VERSION_CODENAME=trixie` et `amd64`. Sinon, s'arrêter.

```bash
pct exec 103 -- bash -lc 'apt update && apt install -y curl gpg ca-certificates'
pct exec 103 -- bash -lc 'install -d -m 0755 /etc/apt/keyrings'
pct exec 103 -- bash -lc 'curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/jellyfin.gpg'
pct exec 103 -- bash -lc 'gpg --show-keys /etc/apt/keyrings/jellyfin.gpg'
```

La clé vient de `https://repo.jellyfin.org` en HTTPS.

**28 oct.** Clé `rsa3072`, empreinte `4918AABC486CA052358D778D49023CD01DE21A7B`, uid `Jellyfin Team <team@jellyfin.org>`. `apt-cache policy` : candidat `jellyfin` **12.4+deb13**, `jellyfin-ffmpeg7` **7.1.4-3-trixie**, tous deux depuis `https://repo.jellyfin.org/debian trixie/main`. Le CT signale 86 paquets Debian à jour disponibles : on ne lance pas `apt upgrade` dans ce pas.

```bash
pct exec 103 -- tee /etc/apt/sources.list.d/jellyfin.sources >/dev/null <<'EOF'
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
pct exec 103 -- bash -lc 'apt update && apt-cache policy jellyfin jellyfin-ffmpeg7'
```

`apt-cache policy` doit citer `https://repo.jellyfin.org/debian`. Puis :

```bash
pct exec 103 -- bash -lc 'apt install -y jellyfin'
pct exec 103 -- bash -lc 'id jellyfin; getent group media'
pct exec 103 -- bash -lc 'usermod -aG media jellyfin && id jellyfin'
pct exec 103 -- systemctl restart jellyfin
pct exec 103 -- systemctl is-active jellyfin
pct exec 103 -- bash -lc 'runuser -u jellyfin -- ls /mnt/mediatheques/films | head'
```

`id` doit contenir le groupe `media`. `ls` tourne sous `jellyfin`, pas sous root : root du CT n'a pas le droit d'entrer dans le dataset.

Santé locale :

```bash
pct exec 103 -- bash -lc 'curl -fsS http://127.0.0.1:8096/health'
```

Attendu : `Healthy`.

**28 oct.** `jellyfin` UID 102, GID 105, groupes `jellyfin`, `video`, `render`, `media` (1000). `systemctl is-active` : `active`. `ls` sous ce compte : dix dossiers de films (`American History X (1998)` en tête). `curl` : `Healthy`.

## 6. Pare-feu du CT

Une règle, écrite même si le pare-feu du datacenter est éteint. **Ne pas** activer le pare-feu datacenter dans ce pas : ça peut couper l'accès à Proxmox.

```bash
cat > /etc/pve/firewall/103.fw <<'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source <réseau-lan> -p tcp -dport 8096
EOF
```

Sortie vers Internet : autorisée (dépôt, mises à jour). Entrée : TCP 8096 depuis `<réseau-lan>` seulement. Pas de 445, pas de redirection sur la box. Pas de hostname dans le tunnel dans ce pas : Access viendra après, origine `http://<ip-jellyfin>:8096`.

## 7. Premier lancement

Depuis un poste du LAN : `http://<ip-jellyfin>:8096`. Mot de passe admin **hors Git**, dans le coffre. Pas `telechargements/`. Pas d'accélération matérielle. Le montage est en lecture seule : ne pas enregistrer les images dans les dossiers des médias.

1. Langue d'affichage : Français. Suivant.
2. Compte admin. Suivant.
3. Trois bibliothèques, bouton **+**, une par une. Dans chaque fenêtre : type, nom, dossier (`+` puis coller le chemin), OK. Laisser décoché « Enregistrer les images dans le dossier du média » s'il est proposé.

| Type (FR) | Type (EN) | Nom | Dossier |
|-----------|-----------|-----|---------|
| Films | Movies | Films | `/mnt/mediatheques/films` |
| Séries | Shows | Séries | `/mnt/mediatheques/series` |
| Musique | Music | Musique | `/mnt/mediatheques/sons` |

4. Langue des métadonnées : `fr`, pays `France`.
5. Réseau : **autoriser les connexions distantes** (sinon le PC du LAN est refusé : « distant » veut dire « pas le conteneur lui-même »). **Désactiver** le mappage de port automatique. Pas de DLNA si la case est là.
6. Terminer. Le scan des 2,1 Tio est long. Dès qu'un film connu apparaît, le lire jusqu'au bout. Pas besoin d'attendre la fin du scan.

**28 oct., après-midi.** Scan terminé. Un film lu jusqu'au bout, sans incident. Titre non relevé.

Lecture VO + sous-titres FR : réglage du **compte**, pas de la bibliothèque. Menu utilisateur → Paramètres → Lecture. Langue audio : pas le français (piste par défaut / originale). Sous-titres : Français. Mode : Toujours. « Intelligent » ne suffit pas si une piste VF existe et que l'audio préféré est le français : Jellyfin choisirait le doublage.

## Retour arrière

Le montage `mp0` ne contient pas une copie. Détruire le CT ne touche pas à `tank/mediatheques`.

```bash
pct stop 103
pct destroy 103
```

Retirer `root:987:1` de `/etc/subgid` seulement si plus aucun CT ne l'utilise. Garder le groupe hôte `media` et les `chgrp` déjà faits. Effacer `/etc/pve/firewall/103.fw` s'il reste.

---

# qBittorrent — décision (28 oct.)

qBittorrent tourne dans un **LXC Debian** à part, CT **104**, `<ip-qbittorrent>`. Le trafic du **compte** `qbittorrent` sort par **Mullvad** (WireGuard). Le reste du CT (mises à jour, `pct exec`) reste sur la box. Pas d'appli Mullvad : elle prendrait toute la machine. Pas de Docker. Pas dans le CT 103 : Jellyfin est en lecture seule, et un client torrent n'a pas le même réseau.

Pourquoi un LXC, comme Jellyfin : le dataset est sur `pve`. `k3s-01` ne le voit pas. Les liens physiques de Sonarr / Radarr exigent ce dataset, plus tard, vus depuis **leur** conteneur.

Montage de ce CT : **seulement** `/tank/mediatheques/telechargements`, en écriture. Le client dépose les fichiers. Il n'a pas à ouvrir `films/`, `series/` ni `sons/`. Sonarr / Radarr, au pas d'après, monteront **tout** le dataset et feront le lien physique de leur côté. Un lien physique ne traverse pas deux datasets ; ici il n'y en a qu'un.

Deux couches, les deux nécessaires :

- **Routage par uid.** `wg-quick` pose les routes `0.0.0.0/0` dans la table `51820`, pas dans la table principale (`Table` numérique, pas `auto`). Une règle envoie l'uid `qbittorrent` dans cette table. Une règle plus prioritaire laisse `<réseau-lan>` sur la table principale : l'interface web, écoutée sur `<ip-qbittorrent>`, reste joignable depuis le LAN. `Table = auto` aurait envoyé tout le CT dans le tunnel, réponses web comprises.
- **nftables.** Cette couche tient quand le tunnel tombe. `wg-quick down` retire la règle uid (c'est voulu : sinon l'uid resterait sans table). Sans nftables, le compte repartirait alors par `eth0` et la box. nftables refuse ce départ : l'uid peut sortir vers `wg0`, vers `lo`, et vers le LAN **sauf** le port 53. Le DNS du CT est `10.64.0.1` (résolveur Mullvad), joignable seulement dans le tunnel. Une réécriture depuis `<ip-box>` a été essayée : la requête directe vers `10.64.0.1` répond, l'application qui croit parler à la box ne reçoit rien. Les autres comptes gardent leur trafic sur la box ; leur résolution passe aussi par `10.64.0.1` (route `/32` dans la table principale). La poignée de main WireGuard n'a pas d'uid : sans exception, le `reject` final la jette et rien ne sort sur `vmbr0`. `FwMark = 51820` marque ces paquets-là, et nftables les accepte. Le compte `qbittorrent` n'a pas cette marque.

Le test de coupure se fait **avant** le premier torrent. Si `curl` vers une IP publique répond encore sous l'uid `qbittorrent` tunnel coupé, on s'arrête.

Ce que les pairs voient : l'IP de sortie Mullvad. La box ne sert qu'à la poignée de main WireGuard (UDP vers le serveur Mullvad) et à l'interface web sur le LAN. Pas de redirection de port sur la box. Pas de hostname dans le tunnel. Le transfert de port Mullvad n'est pas dans ce pas : un téléchargement peut finir sans.

Clé privée WireGuard et mot de passe web : sur le disque du CT (`rpool`) et dans le coffre. Pas dans Git, pas dans ce fichier, pas collés dans le chat. Pas dans `backup-usb` : la sauvegarde des configs est un jalon plus tard.

Ressources : 2 Gio de RAM, 2 cœurs, disque 8 Gio. Le client ne scanne pas les 2,1 Tio et ne transcode pas. Le pare-feu du CT s'écrit (TCP 8080 depuis le LAN). Le pare-feu datacenter reste éteint : la règle ne filtre pas tant qu'il l'est. On ne l'allume pas ici.

Pas d'ADR : un service est tranché, le critère général VM / LXC / K3s reste ouvert.

---

# qBittorrent — procédure

**Pas jouée.** Faire les blocs **dans l'ordre**. En cas d'erreur : coller la sortie. Ne pas `zfs destroy`, ne pas `rm` sur `/tank/mediatheques`, ne pas passer le CT en privilégié, ne pas `chown` le `/dev/net/tun` de l'hôte.

Ne pas coller la clé privée ni le mot de passe web. Le fichier Mullvad ne va pas dans ce dépôt.

## 0. Constat (sur `pve`, root)

```bash
pct list
qm list
ping -c 1 -W 1 <ip-qbittorrent> || true
getent group media
grep -E '^root:' /etc/subgid
free -h
ls /var/lib/vz/template/cache/
modinfo wireguard | sed -n '1,3p'
pve-firewall status || true
ls -ld /tank/mediatheques/telechargements \
  /tank/mediatheques/telechargements/incomplets \
  /tank/mediatheques/telechargements/complets
```

Attendu : pas de CT 104, pas de VM 104, `.70` sans réponse, `media` = 987, `root:987:1` déjà présent (Jellyfin). RAM disponible au moins 2 Gio. Template `debian-13-standard_13.1-2_amd64.tar.zst`. `modinfo` affiche le module `wireguard`. Pare-feu Proxmox : `disabled/running`. Les trois dossiers : `drwxrws---` `root:media`. Sinon, coller et s'arrêter.

**Constat 28 oct., 13:06.** CT 100, 102, 103 en service. VM 101 seule. Pas de 104. `.70` : 100 % de perte. `media` = 987. `subgid` : `root:100000:65536`, `root:988:1`, `root:987:1`. RAM disponible 20 Gio. Template Debian 13 présent. Module `wireguard.ko` (noyau `7.0.14-14-pve`). Pare-feu : `disabled/running`. Trois dossiers `drwxrws---` `root media`. Swap hôte à 0 : sans effet, le CT a son propre swap.

## 1. Module WireGuard sur l'hôte

Le CT partage le noyau de `pve`. Il ne charge pas le module lui-même.

```bash
modprobe wireguard
grep -qx 'wireguard' /etc/modules || echo wireguard >> /etc/modules
```

## 2. Créer le LXC (arrêté)

Même socle que Jellyfin : `vmbr0`, `local-zfs`, non privilégié, Debian 13, `nesting=1`. Moins de RAM et de disque : la config seule vit ici, les fichiers vont sur le bind mount.

```bash
pct create 104 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname qbittorrent \
  --memory 2048 \
  --swap 512 \
  --cores 2 \
  --rootfs local-zfs:8 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,ip=<ip-qbittorrent>/24,gw=<ip-box> \
  --nameserver <ip-box> \
  --unprivileged 1 \
  --features nesting=1 \
  --ostype debian \
  --onboot 1 \
  --start 0
pct set 104 -mp0 /tank/mediatheques/telechargements,mp=/mnt/telechargements
```

## 3. Idmap et `/dev/net/tun`

Même map que le CT 103 : le GID 1000 **dans** le CT est le GID 987 **sur l'hôte**. `root:987:1` est déjà dans `/etc/subgid`. Ne pas l'ajouter une seconde fois.

WireGuard a besoin du périphérique hôte `/dev/net/tun`. Le CT est arrêté.

`unprivileged: 1` ne écrit pas toujours les lignes `lxc.idmap`. Dès qu'on en pose, elles remplacent la map implicite : les quatre lignes, entières. Le script retire les `lxc.idmap` déjà présentes, puis écrit celles du CT 103 et le `tun`. On peut le relancer.

```bash
python3 - << 'PY'
from pathlib import Path
p = Path("/etc/pve/lxc/104.conf")
idmap = [
    "lxc.idmap: u 0 100000 65536",
    "lxc.idmap: g 0 100000 1000",
    "lxc.idmap: g 1000 987 1",
    "lxc.idmap: g 1001 101001 64535",
]
tun = [
    "lxc.cgroup2.devices.allow: c 10:200 rwm",
    "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file",
]
kept = []
for line in p.read_text().splitlines():
    if line.startswith("lxc.idmap:"):
        continue
    if "c 10:200 rwm" in line or "dev/net/tun" in line:
        continue
    kept.append(line)
kept.extend(idmap)
kept.extend(tun)
p.write_text("\n".join(kept) + "\n")
PY
grep -E 'idmap|10:200|dev/net/tun' /etc/pve/lxc/104.conf
pct start 104
pct status 104
pct exec 104 -- ls -l /dev/net/tun
```

Attendu au `grep` : les quatre lignes `lxc.idmap` du CT 103, plus `c 10:200 rwm` et le `mount.entry`. `pct status` : `running`. `ls` : périphérique caractère `10, 200`. S'il manque, ou si `newgidmap` / `Permission denied` : coller, ne pas `chown` le `tun` de l'hôte, ne pas continuer.

`python3` tourne sur **`pve`** (Proxmox l'a déjà). S'il manque : s'arrêter, ne pas installer un paquet sur l'hôte pour ça.

## 4. Groupe, paquet, compte

```bash
pct exec 104 -- bash -lc 'getent group media >/dev/null || groupadd --gid 1000 media'
pct exec 104 -- ls -ld /mnt/telechargements
pct exec 104 -- bash -lc 'apt update && apt-cache policy qbittorrent-nox'
```

`ls` du montage : `nobody media`, `drwxrws---`. Le propriétaire `nobody` est le même cas que Jellyfin (UID 0 de l'hôte hors map). Le groupe `media` prouve la map. Root du CT n'est pas dans `media` et le mode ne donne rien à « other » : un `ls` de `incomplets/` ou `complets/` renvoie `Permission denied`. C'est attendu. L'écriture se teste plus bas, avec le compte `qbittorrent`, après `usermod -aG media`.

`apt-cache policy` : candidat `5.1.0-2` depuis les dépôts Debian. Autre version : s'arrêter (le mot de passe initial et le nom de l'unité peuvent changer).

**28 oct.** `groupadd` sans erreur. `/mnt/telechargements` : `drwxrws--- nobody media`. `ls` des deux sous-dossiers refusé, comme prévu. Suite : `apt-cache policy`, pas encore lancée.

```bash
pct exec 104 -- bash -lc 'apt install -y qbittorrent-nox wireguard-tools nftables curl ca-certificates python3'
pct exec 104 -- bash -lc 'systemctl cat qbittorrent-nox@.service | head -n 40'
```

Paquet `wireguard-tools` seulement. Le métapaquet `wireguard` voudrait un module dans le CT : le module est déjà sur l'hôte.

L'unité attendue est le modèle `qbittorrent-nox@.service` (utilisateur = nom d'instance). Si le `cat` montre autre chose : s'arrêter.

**28 oct.** Unité `/usr/lib/systemd/system/qbittorrent-nox@.service`. `User=%i`, `ExecStart=/usr/bin/qbittorrent-nox`, `TimeoutStopSec=1800`. Pas de `Group=`. Le drop-in plus bas ajoute l'umask et le groupe `media`.

```bash
pct exec 104 -- bash -lc 'getent passwd qbittorrent || adduser --system --group --home /var/lib/qbittorrent --shell /usr/sbin/nologin qbittorrent'
pct exec 104 -- bash -lc 'id qbittorrent; getent passwd qbittorrent'
pct exec 104 -- bash -lc 'usermod -aG media qbittorrent && id qbittorrent'
pct exec 104 -- bash -lc 'systemctl is-enabled qbittorrent-nox@qbittorrent || true; systemctl is-active qbittorrent-nox@qbittorrent || true'
```

`id` contient `media`. Home : `/var/lib/qbittorrent`. Si le paquet a créé le compte avec un autre home : s'arrêter. Service : pas `active`. S'il l'est : `systemctl disable --now qbittorrent-nox@qbittorrent`, puis coller.

**28 oct.** `adduser` a prévenu : `LANG=en_US.UTF-8` absent du CT, repli sur `C`. Le compte est créé quand même. UID 102, GID 105, home `/var/lib/qbittorrent`, shell `nologin`. Après `usermod` : groupes `qbittorrent` et `media` (1000). Service `disabled` / `inactive`. Pas de paquet `locales` dans ce pas.

```bash
pct exec 104 -- bash -lc 'install -d -m 0755 /etc/systemd/system/qbittorrent-nox@qbittorrent.service.d'
pct exec 104 -- tee /etc/systemd/system/qbittorrent-nox@qbittorrent.service.d/override.conf >/dev/null << 'EOF'
[Unit]
After=wg-quick@wg0.service nftables.service
BindsTo=wg-quick@wg0.service
Requires=nftables.service

[Service]
UMask=0007
SupplementaryGroups=media
EOF
pct exec 104 -- systemctl daemon-reload
```

`BindsTo` : si `wg-quick@wg0` s'arrête, qBittorrent s'arrête. `UMask=0007` : fichiers `0660`, dossiers `0770`. Le setgid des dossiers `media` ajoute le bit : `2770`, groupe `media`. On ne démarre pas le service dans ce bloc.

Écriture, sous le compte (pas sous root) :

```bash
pct exec 104 -- runuser -u qbittorrent -- touch /mnt/telechargements/complets/.ecriture-qbt
pct exec 104 -- runuser -u qbittorrent -- ls -l /mnt/telechargements/complets/.ecriture-qbt
pct exec 104 -- runuser -u qbittorrent -- rm /mnt/telechargements/complets/.ecriture-qbt
```

Le `ls` passe par `runuser`. Root du CT n'est pas dans `media` : le même `ls` sans `runuser` renvoie `Permission denied`, même si le fichier est là. Le `touch` prouve l'écriture. Le mode de ce fichier-ci suit l'umask du `runuser`, pas encore celui du service. Le mode `0660` se vérifie sur le torrent de test, plus bas. Le fichier `.ecriture-qbt` ne reste pas.

**28 oct.** Drop-in écrit, `daemon-reload` sans erreur. `touch` puis `ls` sous `qbittorrent` : `-rw-r--r-- 1 qbittorrent media`. Groupe `media` (setgid). Mode `644` : umask du `runuser`, pas celui du service. `rm` sans erreur. Fichier retiré.

## 5. nftables

Le nom `qbittorrent` dans les règles doit déjà exister (bloc 4).

```bash
pct exec 104 -- tee /etc/nftables.conf >/dev/null << 'EOF'
#!/usr/sbin/nft -f
flush ruleset

table inet torrent {
  chain dns {
    type nat hook output priority dstnat; policy accept;
    meta skuid qbittorrent meta nfproto ipv4 udp dport 53 ip daddr != 10.64.0.1 dnat ip to 10.64.0.1
    meta skuid qbittorrent meta nfproto ipv4 tcp dport 53 ip daddr != 10.64.0.1 dnat ip to 10.64.0.1
  }

  chain output {
    type filter hook output priority filter; policy accept;
    meta skuid != qbittorrent accept
    oifname "lo" accept
    oifname "wg0" accept
    ip daddr <réseau-lan> tcp dport 53 reject
    ip daddr <réseau-lan> udp dport 53 reject
    ip daddr <réseau-lan> accept
    meta mark 51820 accept
    reject
  }
}
EOF
pct exec 104 -- systemctl enable nftables
pct exec 104 -- systemctl restart nftables
pct exec 104 -- nft list table inet torrent
```

`enable --now` ne suffit pas. Le paquet démarre déjà le service, avec le fichier Debian d'origine. On réécrit `/etc/nftables.conf` ensuite. Un service `oneshot` déjà `active (exited)` ne relit pas le fichier sur un simple `--now`. `restart` relance `nft -f`.

`nft list` reprend les deux chaînes. Une erreur « Could not process rule: No such file or directory » sur `skuid` veut dire que le compte n'existe pas encore. Si `restart` échoue, coller `systemctl status nftables` et le journal. Ne pas continuer.

**28 oct.** Fichiers en place : `nftables.conf` 644 octets, drop-in 154 octets. Premier `enable --now` n'a pas rechargé le service déjà actif depuis l'installation du paquet. `restart` à 12:26 UTC : `nft -f` code 0. Table `inet torrent` chargée. `skuid` résolu en 102 (`qbittorrent`). Chaînes `dns` et `output` présentes.

## 6. Fichier Mullvad (sur le PC)

Compte Mullvad déjà utilisé sur le téléphone. **Nouvelle clé** : une clé par appareil. Générateur WireGuard du compte (page du compte, « WireGuard configuration »).

L'écran n'affiche d'abord que la plateforme et le bouton de clé. Le pays, la ville, le serveur, le multihop et le content blocking apparaissent **après** « Generate key ».

1. Plateforme : Linux.
2. Generate key. Ne pas quitter la page : Mullvad ne garde pas la clé privée.
3. Un pays, une ville, **un** serveur. « All countries » produit une archive de centaines de fichiers.
4. Multihop : décoché. Protocole vers le serveur : IPv4 et IPv6. Trafic dans le tunnel : les deux. Port : `51820`.
5. « Activer le kill switch (Linux uniquement) » : **décoché**. Cette case écrit les règles de Mullvad dans le fichier. Les nôtres sont déjà dans nftables. Les deux ensembles couperaient aussi le LAN.
6. Blocage de contenu : **Aucun**. « Sélectionner tout » changerait le DNS du fichier.
7. Télécharger le fichier. Pas le QR. Un seul `.conf`.

Ne pas ouvrir le fichier dans le dépôt, ne pas le commiter, ne pas coller la clé.

Le nom du fichier dépend du serveur (`se-mma-wg-001.conf` ou un autre). Le poser sous `/root/wg0.conf` sur `pve` :

```powershell
scp "C:\Users\utilisateur\Downloads\NOM-DU-FICHIER.conf" root@<ip-pve>:/root/wg0.conf
```

Puis, sur `pve` :

```bash
pct exec 104 -- install -d -m 0700 /etc/wireguard
pct push 104 /root/wg0.conf /etc/wireguard/wg0.conf
rm -f /root/wg0.conf
pct exec 104 -- chown root:root /etc/wireguard/wg0.conf
pct exec 104 -- chmod 600 /etc/wireguard/wg0.conf
```

Effacer aussi la copie dans `Downloads` sur le PC. La seule copie restante est `/etc/wireguard/wg0.conf` dans le CT.

Le script retire `DNS =` (sinon `wg-quick` voudrait `resolvconf` pour tout le CT), pose `Table = 51820` et les règles uid. Il refuse un fichier sans `PrivateKey` ou sans `0.0.0.0/0`. Il affiche le résultat **sans** la clé.

```bash
pct exec 104 -- tee /usr/local/sbin/ajuster-wg0.py >/dev/null << 'EOF'
#!/usr/bin/env python3
import pathlib
import subprocess

uid = subprocess.check_output(["id", "-u", "qbittorrent"], text=True).strip()
path = pathlib.Path("/etc/wireguard/wg0.conf")
text = path.read_text().replace("\r\n", "\n").replace("\r", "\n")
if "PrivateKey =" not in text:
    raise SystemExit("PrivateKey absent")
if "0.0.0.0/0" not in text:
    raise SystemExit("AllowedIPs sans 0.0.0.0/0 — fichier inattendu")
kept = []
for line in text.splitlines():
    if line.startswith(("DNS = ", "Table = ", "FwMark = ", "PostUp = ", "PreDown = ")):
        continue
    kept.append(line)
extra = [
    "Table = 51820",
    "FwMark = 51820",
    f"PostUp = ip rule del uidrange {uid}-{uid} lookup 51820 priority 200 || true",
    f"PostUp = ip rule add uidrange {uid}-{uid} lookup 51820 priority 200",
    f"PostUp = ip -6 rule del uidrange {uid}-{uid} lookup 51820 priority 200 || true",
    f"PostUp = ip -6 rule add uidrange {uid}-{uid} lookup 51820 priority 200",
    "PostUp = ip rule del to <réseau-lan> lookup main priority 100 || true",
    "PostUp = ip rule add to <réseau-lan> lookup main priority 100",
    "PostUp = ip route replace 10.64.0.1/32 dev wg0",
    f"PreDown = ip rule del uidrange {uid}-{uid} lookup 51820 priority 200 || true",
    f"PreDown = ip -6 rule del uidrange {uid}-{uid} lookup 51820 priority 200 || true",
    "PreDown = ip rule del to <réseau-lan> lookup main priority 100 || true",
    "PreDown = ip route del 10.64.0.1/32 dev wg0 || true",
]
out = []
inserted = False
for line in kept:
    out.append(line)
    if line.strip() == "[Interface]" and not inserted:
        out.extend(extra)
        inserted = True
if not inserted:
    raise SystemExit("pas de [Interface]")
path.write_text("\n".join(out) + "\n")
path.chmod(0o600)
for line in out:
    if line.startswith("PrivateKey"):
        print("PrivateKey = [présent]")
    else:
        print(line)
EOF
pct exec 104 -- python3 /usr/local/sbin/ajuster-wg0.py
```

La sortie collée, s'il faut la coller, est celle **déjà** rédigée (`PrivateKey = [présent]`). `Address` est l'adresse interne Mullvad. `Endpoint` est le serveur choisi.

## 7. Tunnel, puis coupure

```bash
pct exec 104 -- wg-quick up wg0
pct exec 104 -- wg show
pct exec 104 -- ip rule
pct exec 104 -- ip route show table 51820
```

`wg show` : une poignée de main récente (`latest handshake`). `ip rule` : priorité 100 vers `<réseau-lan>` / table `main`, priorité 200 uid du compte / table `51820`. Table `51820` : `default dev wg0`.

Contrôle. Le compte sort par Mullvad. Root sort par la box.

```bash
pct exec 104 -- runuser -u qbittorrent -- curl -4 -fsS --max-time 20 https://am.i.mullvad.net/json
pct exec 104 -- curl -4 -fsS --max-time 20 https://am.i.mullvad.net/json
```

La première réponse a `"mullvad_exit_ip": true`. La seconde (root) a `"mullvad_exit_ip": false`. Si les deux sont `true`, tout le CT est dans le tunnel : s'arrêter. Si le compte est `false`, il sort par la box : s'arrêter.

**28 oct.** `wg-quick@wg0` repris par systemd : `active`. Compte toujours sur Mullvad `fr-mrs-wg-002` (`mullvad_exit_ip` true). qBittorrent pas encore démarré.

Coupure, nftables toujours chargé :

```bash
pct exec 104 -- wg-quick down wg0
pct exec 104 -- nft list table inet torrent >/dev/null
pct exec 104 -- runuser -u qbittorrent -- curl -4 --max-time 10 -o /dev/null -w '%{http_code}\n' http://1.1.1.1 || true
pct exec 104 -- curl -4 --max-time 10 -o /dev/null -s -w '%{http_code}\n' http://1.1.1.1
```

Attendu pour le compte : `000` (la connexion ne part pas). Attendu pour root : `301`. Un `301` ou `200` **pour le compte** veut dire que l'IP de la box a répondu : ne pas lancer qBittorrent.

Remettre le tunnel :

```bash
pct exec 104 -- wg-quick up wg0
pct exec 104 -- runuser -u qbittorrent -- curl -4 -fsS --max-time 20 https://am.i.mullvad.net/json
```

De nouveau `"mullvad_exit_ip": true`. Puis au démarrage :

```bash
pct exec 104 -- systemctl enable --now wg-quick@wg0
```

## 8. Service qBittorrent

```bash
pct exec 104 -- systemctl enable --now qbittorrent-nox@qbittorrent
pct exec 104 -- systemctl is-active qbittorrent-nox@qbittorrent
pct exec 104 -- bash -lc 'journalctl -u qbittorrent-nox@qbittorrent -b --no-pager -o cat | grep -i "temporary password" | tail -n 1'
```

`active`. La ligne du journal contient le mot de passe temporaire du compte web `admin` (qBittorrent 5.1, Debian 13). Le copier dans le coffre. Ne pas le coller ici. Pas de mot de passe `adminadmin` : ça, c'était Debian 12.

## 9. Pare-feu du CT

Même geste que Jellyfin. **Ne pas** activer le pare-feu datacenter.

```bash
cat > /etc/pve/firewall/104.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source <réseau-lan> -p tcp -dport 8080
EOF
```

Le pare-feu du datacenter reste éteint : ce fichier ne filtre pas tant qu'il l'est. On ne l'allume pas.

**28 oct.** Service `qbittorrent-nox@qbittorrent` actif. Mot de passe temporaire dans le coffre, pas dans le journal du dépôt. `/etc/pve/firewall/104.fw` écrit (8080 depuis le LAN). Interface web réglée : écoute `<ip-qbittorrent>:8080`, chemins `complets/` et `incomplets/`, mode manuel, UPnP décoché, interface `wg0`. Torrent de test pas encore ajouté.

## 10. Interface web

Depuis un poste du LAN : `http://<ip-qbittorrent>:8080`. UI en anglais au premier lancement. Mot de passe : celui du journal, puis un mot de passe à soi, dans le coffre.

Réglages (icône engrenage), dans cet ordre. Appliquer à chaque page.

1. **Web UI**. IP address : `<ip-qbittorrent>`. Port : `8080`. Authentication : changer le mot de passe. La page peut couper ; rouvrir `http://<ip-qbittorrent>:8080`.
2. **Downloads**. Default Torrent Management Mode : Manual. Default Save Path : `/mnt/telechargements/complets`. Cocher « Keep incomplete torrents in » : `/mnt/telechargements/incomplets`.
3. **Connection**. Décocher « Use UPnP / NAT-PMP port forwarding from my router ».
4. **Advanced**. Network interface : `wg0`.

Pas de torrent avant ces quatre pages. L'interface `wg0` fixe les sockets du protocole sur le tunnel. nftables reste la couche qui bloque `eth0` si ce réglage manque.

## 11. Un fichier de test

Un torrent public, page de l'éditeur (image Debian netinst, `debian.org`). Pas un aimant collé dans ce fichier : la page change.

Le fichier apparaît dans `/mnt/telechargements/complets` (il passe d'abord par `incomplets/`). Sur `pve` :

```bash
ls -l /tank/mediatheques/telechargements/complets
```

Attendu : groupe `media`, mode `rw-rw----` (`0660`). Un dossier de torrent : `drwxrws---` (`2770`). Sur l'hôte, le propriétaire s'affiche `100102` : UID 102 du CT, décalé de `100000` (conteneur non privilégié).

**28 oct.** `debian-13.7.0-amd64-netinst.iso`, 792723456 octets, `-rw-rw---- 1 100102 media`. Torrent et fichiers supprimés. `complets/` et `incomplets/` : `total 0`.

Puis, dans l'interface : supprimer ce torrent **et** ses fichiers. `complets/` ne garde pas l'image. Jellyfin n'indexe pas ce dossier.

## Retour arrière

Le montage ne contient pas une copie de la bibliothèque. Détruire le CT ne touche pas à `films/`, `series/` ni `sons/`. Il emporte la clé WireGuard et la config qBittorrent qui sont sur son disque.

S'il reste un fichier de test :

```bash
rm -f /tank/mediatheques/telechargements/complets/.ecriture-qbt
```

Puis :

```bash
pct stop 104
pct destroy 104
rm -f /etc/pve/firewall/104.fw
```

Garder `root:987:1` dans `/etc/subgid` : le CT 103 s'en sert. Garder le groupe hôte `media`. La ligne `wireguard` dans `/etc/modules` peut rester : elle charge un module, elle n'ouvre pas de tunnel.

---

# Ensuite

1. Prowlarr, puis Sonarr / Radarr. Ils monteront tout `tank/mediatheques` pour les liens physiques. qBittorrent ne retire pas le torrent en fin de téléchargement : Sonarr et Radarr le retirent après un import réussi. Les fichiers restent.
2. SMB `Mediatheques` seulement si l'Explorateur doit écrire ici : idmap du CT 102 à étendre, sans casser `perso`.
