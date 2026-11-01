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

Ce que les pairs voient : l'IP de sortie Mullvad. La box ne sert qu'à la poignée de main WireGuard (UDP vers le serveur Mullvad) et à l'interface web sur le LAN. Pas de redirection de port sur la box. Pas de hostname dans le tunnel. Mullvad a retiré le transfert de port le 29 mai 2023 (ports existants effacés le 1er juillet 2023). La FAQ le dit encore : on ne peut plus en associer un à une clé WireGuard. Un port d'écoute écrit dans qBittorrent n'ouvre rien chez Mullvad. Un torrent peut quand même finir si d'autres pairs acceptent la connexion sortante. Si les deux côtés sont fermés, personne ne se joint.

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

# Prowlarr — décision (28 oct.)

Prowlarr, Sonarr et Radarr tournent dans **un** LXC Debian, CT **105** `servarr`, `<ip-servarr>`. Ce pas installe **Prowlarr seul**. Sonarr et Radarr viendront dans ce CT, une fois l'interface ouverte. Pas de Docker. Pas dans K3s. Pas dans le CT 103 ni le CT 104.

Pourquoi ce LXC, et pas la VM :

- Sonarr et Radarr font un lien physique depuis `telechargements/` vers `films/` ou `series/`. Le lien reste dans `tank/mediatheques`. `k3s-01` ne voit pas ce dataset. Un partage NFS ou un zvol sous `tank/vmdata` rangerait 2,1 Tio au mauvais endroit (ADR-008).
- Cette VM héberge Vaultwarden. Les imports n'y passent pas.
- Le CT 103 monte le dataset en lecture seule, pour Jellyfin.
- Le CT 104 envoie le compte `qbittorrent` dans Mullvad. Prowlarr joint des indexeurs et, plus tard, qBittorrent sur le LAN : son trafic sort par la box, comme Jellyfin.

Montage de ce CT : **tout** `/tank/mediatheques`, en écriture, sur `/mnt/mediatheques`. Prowlarr n'écrit pas dedans. Le montage est posé maintenant : Sonarr et Radarr s'en serviront sans recréer le CT. qBittorrent continue de ne voir que `telechargements/`, sous `/mnt/telechargements` **chez lui**. Le chemin n'est pas le même. Sonarr et Radarr auront un mappage de chemin distant. Pas dans ce pas.

qBittorrent ne retire pas le torrent en fin de téléchargement. Sonarr et Radarr le retireront après un import réussi. Les fichiers restent.

Le compte `prowlarr` ne rejoint pas `media` : il ne lit pas les fichiers. Le groupe `media` (GID 1000 dans le CT = 987 sur l'hôte) existe pour que le montage porte le bon nom, et pour Sonarr / Radarr ensuite. Les fichiers déposés par qBittorrent sont déjà `0660` `media`.

Config (`/var/lib/prowlarr`) et binaire (`/opt/Prowlarr`) : disque du CT, sur `rpool`. C'est elle qu'il faudra sauvegarder plus tard, pas les médias. Pas dans ce pas. Mot de passe web : dans le coffre. Pas dans Git, pas dans ce fichier, pas collé dans le chat.

Ressources prévues pour les trois applis : 4 Gio de RAM, 2 cœurs, disque 16 Gio. On n'en installe qu'une. Le pare-feu du CT s'écrit (TCP 9696 depuis le LAN). Les ports 8989 et 7878 attendront Sonarr et Radarr. Le pare-feu datacenter reste éteint. On ne l'allume pas ici. LAN seulement, pas de hostname dans le tunnel.

Pas d'ADR : un hébergement est tranché pour Prowlarr, Sonarr et Radarr. Bazarr : même CT, procédure plus bas. Le critère VM / LXC / K3s reste ouvert pour Recyclarr, Lidarr, Navidrome.

Branche `master` du binaire : c'est la branche stable chez Servarr. `develop` est la branche de test.

---

# Prowlarr — procédure

**As-built 28 oct.** CT **105** `servarr`, `<ip-servarr>`, **running**. Prowlarr **2.7.0.5723**, service `active`, `curl` local `200`. Compte web `utilisateur`, authentification Forms, **Enabled**. Mot de passe dans le coffre. **Allowed Hosts** vide. Pas d'indexeur. `/etc/pve/firewall/105.fw` écrit (TCP 9696 depuis le LAN). Le pare-feu datacenter reste éteint.

Pas le script d'installation Servarr : il est interactif et il efface `/opt` s'il réinstalle. Les commandes du wiki, une par une. Pas d'`apt upgrade`.

## 0. Constat (sur `pve`, root)

```bash
pct list
qm list
ping -c 1 -W 1 <ip-servarr> || true
getent group media
grep -E '^root:' /etc/subgid
free -h
ls /var/lib/vz/template/cache/
pve-firewall status || true
ls -ld /tank/mediatheques \
  /tank/mediatheques/films \
  /tank/mediatheques/series \
  /tank/mediatheques/sons \
  /tank/mediatheques/telechargements \
  /tank/mediatheques/telechargements/complets
```

Attendu : pas de CT 105, pas de VM 105, `.80` sans réponse, `media` = 987, `root:987:1` déjà présent, au moins 4 Gio disponibles, template `debian-13-standard_13.1-2_amd64.tar.zst`, pare-feu `disabled/running`, dossiers `drwxrws---` `root:media`.

**Constat 28 oct., 17:38.** CT 100, 102, 103, 104 en service. VM 101 seule. Pas de 105. `.80` : 100 % de perte. `media` = 987. `subgid` : `root:100000:65536`, `root:988:1`, `root:987:1`. RAM disponible 20 Gio. Template Debian 13 présent. Pare-feu : `disabled/running`. Dossiers `drwxrws---` `root media`. `complets/` vide (deux liens, le dossier lui-même). Swap hôte à 0 : sans effet, le CT a son propre swap.

## 1. Créer le LXC (arrêté)

Même socle que Jellyfin : `vmbr0`, `local-zfs`, non privilégié, Debian 13, `nesting=1`. 4 Gio, 2 cœurs, 16 Gio : la config des trois applis vivra ici, les médias restent sur le bind mount. `root:987:1` est déjà dans `/etc/subgid`. Ne pas l'ajouter une seconde fois.

```bash
pct create 105 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname servarr \
  --memory 4096 \
  --swap 512 \
  --cores 2 \
  --rootfs local-zfs:16 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,ip=<ip-servarr>/24,gw=<ip-box> \
  --nameserver <ip-box> \
  --unprivileged 1 \
  --features nesting=1 \
  --ostype debian \
  --onboot 1 \
  --start 0
pct set 105 -mp0 /tank/mediatheques,mp=/mnt/mediatheques
grep mp0 /etc/pve/lxc/105.conf
```

Attendu : une ligne `mp0` **sans** `ro=1`. Si `ro=1` est là : s'arrêter, ne pas démarrer.

**28 oct., 17:43.** CT 105 créé, architecture `amd64`. `mp0: /tank/mediatheques,mp=/mnt/mediatheques`, sans `ro=1`.

## 2. Idmap

Même map que les CT 103 et 104. Le GID 1000 **dans** le CT est le GID 987 **sur l'hôte**. Pas de `/dev/net/tun` : ce CT ne fait pas de WireGuard.

`unprivileged: 1` ne écrit pas toujours les lignes `lxc.idmap`. Dès qu'on en pose, elles remplacent la map implicite : les quatre lignes, entières. Le script retire les `lxc.idmap` déjà présentes, puis écrit celles du CT 103. On peut le relancer.

```bash
python3 - << 'PY'
from pathlib import Path
p = Path("/etc/pve/lxc/105.conf")
idmap = [
    "lxc.idmap: u 0 100000 65536",
    "lxc.idmap: g 0 100000 1000",
    "lxc.idmap: g 1000 987 1",
    "lxc.idmap: g 1001 101001 64535",
]
kept = [line for line in p.read_text().splitlines() if not line.startswith("lxc.idmap:")]
kept.extend(idmap)
p.write_text("\n".join(kept) + "\n")
PY
grep idmap /etc/pve/lxc/105.conf
pct start 105
pct status 105
```

Attendu au `grep` : les quatre lignes, dans cet ordre. `pct status` : `running`. Si `newgidmap` / `not allowed` : coller, ne pas continuer.

`python3` tourne sur **`pve`**. S'il manque : s'arrêter, ne pas installer un paquet sur l'hôte pour ça.

**28 oct., 17:43.** Quatre lignes `lxc.idmap`, dans l'ordre. `pct start` sans erreur. `status: running`.

## 3. Groupe

```bash
pct exec 105 -- bash -lc 'getent group media >/dev/null || groupadd --gid 1000 media'
pct exec 105 -- ls -ld /mnt/mediatheques
```

Attendu : `drwxrws---` `nobody media`. Le propriétaire `nobody` est le même cas que Jellyfin (UID 0 de l'hôte hors map). Le groupe `media` prouve la map. Root du CT n'entre pas dans `films/` : il n'est pas dans `media`. C'est attendu. On ne teste pas l'écriture dans ce pas : Prowlarr ne touche pas aux fichiers. Sonarr le fera.

**28 oct., 17:46.** `groupadd` sans erreur. `/mnt/mediatheques` : `drwxrws---` `nobody media`.

## 4. Compte et binaire

```bash
pct exec 105 -- bash -lc 'cat /etc/os-release; dpkg --print-architecture'
```

Attendu : `VERSION_CODENAME=trixie` et `amd64`. Sinon, s'arrêter.

```bash
pct exec 105 -- bash -lc 'apt update && apt install -y curl ca-certificates sqlite3'
pct exec 105 -- bash -lc 'getent passwd prowlarr || adduser --system --group --home /var/lib/prowlarr --shell /usr/sbin/nologin prowlarr'
pct exec 105 -- bash -lc 'install -d -o prowlarr -g prowlarr -m 0750 /var/lib/prowlarr'
pct exec 105 -- bash -lc 'id prowlarr; getent passwd prowlarr'
```

`prowlarr` existe, home `/var/lib/prowlarr`, shell `nologin`. Le groupe `media` n'est **pas** dans `id` : voulu. `adduser` peut prévenir que `LANG=en_US.UTF-8` manque : le compte est créé quand même, comme sur le CT 104. Pas de paquet `locales` dans ce pas.

**28 oct., 17:46.** `trixie`, `amd64`. `curl`, `ca-certificates` et `sqlite3` installés. `apt` a aussi mis à jour `ca-certificates` et `libsqlite3-0`, tirés par cette installation. 85 paquets restent non mis à jour : pas d'`apt upgrade`. Avertissements de locale (`LANG=en_US.UTF-8` absent) : compte créé quand même. `prowlarr` UID 102, GID 105, home `/var/lib/prowlarr`, shell `nologin`, groupe `prowlarr` seul. Archive `92.2M` téléchargée. `tar -tzf | head` liste `Prowlarr/` en tête, puis `tar: stdout: write error` : `head` ferme le tuyau, l'archive n'est pas en cause. Pas encore extraite.

Puis le binaire. L'archive vient de `https://prowlarr.servarr.com` (branche `master`). Si `/opt/Prowlarr` existe déjà : s'arrêter.

```bash
pct exec 105 -- bash -lc 'test ! -e /opt/Prowlarr'
pct exec 105 -- bash -lc 'curl -fL --retry 3 -o /tmp/Prowlarr.tar.gz "https://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64"'
pct exec 105 -- bash -lc 'tar -tzf /tmp/Prowlarr.tar.gz | head'
```

Les chemins de l'archive commencent par `Prowlarr/`. Sinon : s'arrêter, ne pas extraire.

```bash
pct exec 105 -- bash -lc 'tar -xzf /tmp/Prowlarr.tar.gz -C /opt && chown -R prowlarr:prowlarr /opt/Prowlarr && rm -f /tmp/Prowlarr.tar.gz'
pct exec 105 -- bash -lc 'ls -ld /opt/Prowlarr /opt/Prowlarr/Prowlarr'
```

Le répertoire et le binaire appartiennent à `prowlarr`. L'utilisateur du service doit pouvoir mettre à jour `/opt/Prowlarr` tout seul.

Unité systemd, celle du wiki :

```bash
pct exec 105 -- tee /etc/systemd/system/prowlarr.service >/dev/null << 'EOF'
[Unit]
Description=Prowlarr Daemon
After=syslog.target network.target

[Service]
User=prowlarr
Group=prowlarr
Type=simple
ExecStart=/opt/Prowlarr/Prowlarr -nobrowser -data=/var/lib/prowlarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
pct exec 105 -- systemctl daemon-reload
pct exec 105 -- systemctl enable --now prowlarr
pct exec 105 -- systemctl is-active prowlarr
pct exec 105 -- bash -lc 'curl -sS -o /dev/null -w "%{http_code}\n" --max-time 20 http://127.0.0.1:9696 || true'
```

`active`. Code HTTP `200` ou `302`. Un `000` : attendre dix secondes et relancer le `curl`. Encore `000` : coller `systemctl status prowlarr` et `journalctl -u prowlarr -b --no-pager | tail -n 20`. Ne pas retélécharger l'archive.

**28 oct., 17:49.** `gzip -t` : `OK`. Binaire extrait, `prowlarr:prowlarr`, horodaté 26 oct. 18:06 dans l'archive. Unité activée. `is-active` : `active`. `curl` local : `200`. Journal : `Starting Prowlarr - /opt/Prowlarr/Prowlarr - Version 2.7.0.5723`.

## 5. Pare-feu du CT

Même geste que Jellyfin. **Ne pas** activer le pare-feu datacenter.

```bash
cat > /etc/pve/firewall/105.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source <réseau-lan> -p tcp -dport 9696
EOF
```

Le pare-feu du datacenter reste éteint : ce fichier ne filtre pas tant qu'il l'est. On ne l'allume pas. Sortie vers Internet : autorisée. Entrée : TCP 9696 depuis le LAN. Pas de 8989, pas de 7878, pas de redirection sur la box.

**28 oct., 17:53.** `/etc/pve/firewall/105.fw` écrit. Datacenter toujours éteint.

## 6. Interface web

Depuis un poste du LAN : `http://<ip-servarr>:9696`.

La première page demande une authentification. Créer le compte. Mot de passe dans le coffre. Ne pas le coller ici.

S'arrêter là. Pas d'indexeur, pas de Sonarr, pas de Radarr : les deux applis n'existent pas encore. Un indexeur se branche quand Sonarr est là pour le recevoir.

**28 oct., 17:53.** Page d'authentification : Forms, **Enabled**, utilisateur `utilisateur`, **Allowed Hosts** vide. Mot de passe dans le coffre. Connecté. Pas d'indexeur.

## Retour arrière

Le montage ne contient pas une copie. Détruire le CT ne touche pas à `tank/mediatheques`. Il emporte la config Prowlarr qui est sur son disque.

```bash
pct stop 105
pct destroy 105
rm -f /etc/pve/firewall/105.fw
```

Garder `root:987:1` dans `/etc/subgid` : les CT 103 et 104 s'en servent. Garder le groupe hôte `media`.

---

# Sonarr — décision (28 oct.)

Sonarr s'installe dans le CT **105**, à côté de Prowlarr. Même montage `/mnt/mediatheques`, en écriture. Le dossier des séries sera `/mnt/mediatheques/series`. Pas un nouveau CT. Pas de Docker. Pas le script d'installation : les commandes du wiki, une par une.

Le compte `sonarr` rejoint `media`. qBittorrent dépose des fichiers `0660` `media`. Sonarr doit pouvoir les lire et créer le lien physique dans `series/`. Les dossiers du dataset sont `2770` (setgid) : un fichier créé dedans prend le groupe `media`.

L'unité systemd pose `UMask=0007`. Le wiki propose `0002`, qui laisse les fichiers lisibles par les autres (`0664`). Ici les autres n'ont rien : `0660` et `2770`. `Group=sonarr`, avec `SupplementaryGroups=media`. La config (`/var/lib/sonarr`) reste à `sonarr` seul. Le groupe `media` ne sert qu'aux fichiers du dataset.

Branche `main`, Sonarr v4. Chez Sonarr la branche stable s'appelle `main`. Chez Prowlarr elle s'appelle `master`.

Le mappage de chemin vers qBittorrent (`/mnt/telechargements` chez lui, `/mnt/mediatheques/telechargements` ici) et le dossier racine des séries viennent **après** le compte web. Pas dans les blocs d'installation.

Port **8989**. On l'ajoute à `105.fw` à côté du 9696. On ne retire pas la règle Prowlarr. Le pare-feu datacenter reste éteint.

---

# Sonarr — procédure

**As-built 28 oct., installation.** CT 105 déjà en service. Sonarr **4.0.20.3014**, `active`, `curl` local `200`. Compte web créé, connecté. `/etc/pve/firewall/105.fw` : TCP 9696 et 8989 depuis le LAN. Datacenter éteint. Dossier racine, client et Prowlarr : pas encore branchés.

`curl` et `sqlite3` sont déjà là. Pas d'`apt upgrade`.

## 1. Compte

```bash
pct exec 105 -- bash -lc 'getent passwd sonarr || adduser --system --group --home /var/lib/sonarr --shell /usr/sbin/nologin sonarr'
pct exec 105 -- bash -lc 'install -d -o sonarr -g sonarr -m 0750 /var/lib/sonarr'
pct exec 105 -- bash -lc 'usermod -aG media sonarr && id sonarr'
```

`id` contient `media` (1000). Home `/var/lib/sonarr`, shell `nologin`. `adduser` peut prévenir que `LANG=en_US.UTF-8` manque : le compte est créé quand même. Pas de paquet `locales`.

**28 oct., 17:56.** Avertissement de locale, compte créé. UID 103, GID 106, groupes `sonarr` et `media` (1000).

## 2. Écriture

Le `umask` du service n'est pas celui d'un `touch` lancé à la main. On le pose dans la commande. Le fichier d'essai est effacé tout de suite.

```bash
pct exec 105 -- bash -lc 'runuser -u sonarr -- bash -c "umask 0007; touch /mnt/mediatheques/telechargements/complets/.ecriture-sonarr"'
ls -l /tank/mediatheques/telechargements/complets/.ecriture-sonarr
rm -f /tank/mediatheques/telechargements/complets/.ecriture-sonarr
```

Attendu : `-rw-rw----`, groupe `media`. Le propriétaire affiché sur l'hôte est l'UID du CT décalé de `100000`. `Permission denied` : s'arrêter, ne pas télécharger Sonarr.

**28 oct., 17:56.** `-rw-rw---- 1 100103 media`. Fichier effacé.

## 3. Binaire

L'archive vient de `https://services.sonarr.tv`, branche `main`, v4. Si `/opt/Sonarr` existe déjà : s'arrêter.

```bash
pct exec 105 -- bash -lc 'test ! -e /opt/Sonarr'
pct exec 105 -- bash -lc 'curl -fL --retry 3 -o /tmp/Sonarr.tar.gz "https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=x64"'
pct exec 105 -- bash -lc 'gzip -t /tmp/Sonarr.tar.gz && echo OK'
pct exec 105 -- bash -lc 'tar -tzf /tmp/Sonarr.tar.gz | head'
```

`OK`. Les chemins commencent par `Sonarr/`. Un `tar: stdout: write error` après ces lignes vient de `head`, comme pour Prowlarr. Sinon : s'arrêter, ne pas extraire.

**28 oct., 17:57.** Archive `97.4M`. `gzip -t` : `OK`. Liste en tête `Sonarr/`, puis `tar: stdout: write error` (`head`). Pas encore extraite.

```bash
pct exec 105 -- bash -lc 'tar -xzf /tmp/Sonarr.tar.gz -C /opt && chown -R sonarr:sonarr /opt/Sonarr && rm -f /tmp/Sonarr.tar.gz'
pct exec 105 -- bash -lc 'ls -ld /opt/Sonarr /opt/Sonarr/Sonarr'
pct exec 105 -- tee /etc/systemd/system/sonarr.service >/dev/null << 'EOF'
[Unit]
Description=Sonarr Daemon
After=syslog.target network.target

[Service]
User=sonarr
Group=sonarr
SupplementaryGroups=media
UMask=0007
Type=simple
ExecStart=/opt/Sonarr/Sonarr -nobrowser -data=/var/lib/sonarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
pct exec 105 -- systemctl daemon-reload
pct exec 105 -- systemctl enable --now sonarr
pct exec 105 -- systemctl is-active sonarr
pct exec 105 -- bash -lc 'curl -sS -o /dev/null -w "%{http_code}\n" --max-time 30 http://127.0.0.1:8989 || true'
```

Le répertoire et le binaire appartiennent à `sonarr`. `active`. Code HTTP `200` ou `302`. Un `000` : attendre dix secondes et relancer le `curl`. Encore `000` : coller `systemctl status sonarr` et `journalctl -u sonarr -b --no-pager | tail -n 20`. Ne pas retélécharger l'archive.

**28 oct., 17:59.** Binaire extrait, `sonarr:sonarr`, horodaté 16 sep. 16:37 dans l'archive. Unité activée. `is-active` : `active`. `curl` local : `200`. Journal : `Starting Sonarr - /opt/Sonarr/Sonarr - Version 4.0.20.3014`.

## 4. Pare-feu du CT

Les deux ports. Remplacer le fichier : la règle 9696 reste.

```bash
cat > /etc/pve/firewall/105.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source <réseau-lan> -p tcp -dport 9696
IN ACCEPT -source <réseau-lan> -p tcp -dport 8989
EOF
```

**Ne pas** activer le pare-feu datacenter. Pas de 7878 dans ce pas.

**28 oct., 18:01.** Fichier réécrit : 9696 et 8989. Datacenter toujours éteint.

## 5. Interface web

Depuis un poste du LAN : `http://<ip-servarr>:8989`.

Même page que Prowlarr. **Forms**, **Enabled**, un mot de passe dans le coffre. **Allowed Hosts** vide. Ne pas coller le mot de passe ici.

S'arrêter là. Pas de dossier racine, pas de client de téléchargement, pas de Prowlarr, pas de série. Ça se branche au pas d'après.

**28 oct., 18:01.** Connecté. Nom du compte non relevé. Mot de passe dans le coffre. Pas de dossier racine, pas de client, pas de série.

## Retour arrière

Arrêter Sonarr et retirer ses fichiers ne touche pas à Prowlarr ni à `tank/mediatheques`.

```bash
pct exec 105 -- systemctl disable --now sonarr
pct exec 105 -- rm -rf /opt/Sonarr /var/lib/sonarr /etc/systemd/system/sonarr.service
pct exec 105 -- systemctl daemon-reload
pct exec 105 -- bash -lc 'deluser sonarr || true'
```

Remettre `105.fw` avec la seule règle 9696. Garder le groupe `media` et le compte `prowlarr`.

---

# Sonarr — branchement

**As-built 28 oct., 18:14.** Dossier `series/`, client qBittorrent, mappage de chemin, application Prowlarr : **Test** réussi. Pas d'indexeur. Pas de série ajoutée.

## 1. Dossier et liens

`http://<ip-servarr>:8989` → **Settings** → **Media Management**.

1. **Root Folders** → **Add Root Folder** → `/mnt/mediatheques/series` → OK.
2. **Importing** → **Use Hardlinks instead of Copy** : coché.
3. **Permissions** → **Set Permissions** : décoché. Le `UMask=0007` du service suffit. Cocher cette case ferait un `chmod` qui enlève le setgid des dossiers.

**Save** s'il y a un bouton en haut de la page.

**28 oct., 18:05.** Dossier racine `/mnt/mediatheques/series`. 5 Tio libres, 78 dossiers non suivis : la copie déjà là, pas des séries ajoutées dans Sonarr. Case des liens physiques : ouverte via **Show Advanced**, pas relue à l'écran.

## 2. qBittorrent

**Settings** → **Download Clients**.

En haut : **Completed Download Handling** coché. **Remove Completed Downloads** : le laisser comme Sonarr le propose. Sonarr retire le torrent du client quand le seed est terminé. Le lien physique dans `series/` garde le fichier. On ne règle pas de ratio ici. qBittorrent, de son côté, ne retire rien tout seul.

**+** → **qBittorrent**.

| Champ | Valeur |
|-------|--------|
| Name | `qBittorrent` |
| Host | `<ip-qbittorrent>` |
| Port | `8080` |
| Username | le compte web déjà posé sur qBittorrent |
| Password | celui du coffre |
| Category | `tv-sonarr` |

**Test**. Il doit réussir. **Save**.

En bas de la même page, **Remote Path Mappings** → **+**.

| Champ | Valeur |
|-------|--------|
| Host | `<ip-qbittorrent>` |
| Remote Path | `/mnt/telechargements/` |
| Local Path | `/mnt/mediatheques/telechargements/` |

Le Host est exactement celui du client. Le chemin distant est celui que qBittorrent annonce. Le chemin local est le même dossier, vu depuis ce CT. **Save**.

**28 oct., 18:12.** Client `qBittorrent`, `<ip-qbittorrent>:8080`, compte `admin`, catégorie `tv-sonarr`. SSL, URL base et clé d'API vides. **Remove Completed** coché. **Post-Import Category** vide. Mappage enregistré avec les barres finales. Un `Invalid Path` est apparu puis a disparu sur le même chemin : l'interface, pas le dossier.

## 3. Prowlarr

Dans Prowlarr, `http://<ip-servarr>:9696` → **Settings** → **Apps** → **+** → **Sonarr**.

La clé d'API est dans Sonarr → **Settings** → **General** → **Security**. La copier dans le coffre et dans ce formulaire. Ne pas la coller ici.

| Champ | Valeur |
|-------|--------|
| Prowlarr Server | `http://<ip-servarr>:9696` |
| Sonarr Server | `http://<ip-servarr>:8989` |
| API Key | la clé Sonarr |
| Sync Level | Full Sync |

**Test**, puis **Save**. Pas d'indexeur dans ce pas.

S'arrêter. Pas de série ajoutée. Le fichier de test viendra après.

**28 oct., 18:14.** Application Sonarr dans Prowlarr : **Test** réussi. Pas d'indexeur.

**28 oct., 18:20.** Série *Cold Case* ajoutée. Chemin `/mnt/mediatheques/series/Cold Case`, 178,9 Gio, profil **Any**, surveillée. Saisons vues complètes : 7 (22/22), 6 (23/23), 5 (18/18), 4 (24/24). Les fichiers déjà là sont reconnus. Pas de téléchargement.

---

# Radarr — décision (28 oct.)

Radarr s'installe dans le CT **105**, à côté de Prowlarr et Sonarr. Même montage. Le dossier des films sera `/mnt/mediatheques/films`. Même compte que Sonarr pour le groupe : `radarr` dans `media`, `UMask=0007`, `Group=radarr`, `SupplementaryGroups=media`. La config reste dans `/var/lib/radarr`.

Branche `master`. Chez Radarr, comme chez Prowlarr, la branche stable s'appelle `master`.

Le client qBittorrent, le mappage de chemin et Prowlarr viennent **après** le compte web. Pas dans les blocs d'installation. Catégorie prévue : on la lira dans le formulaire, on ne l'invente pas.

Port **7878**, ajouté à `105.fw` à côté de 9696 et 8989. Le pare-feu datacenter reste éteint.

---

# Radarr — procédure

**As-built 28 oct., installation.** Radarr **6.4.4.10685**, `active`, `curl` local `200`. Compte web créé, connecté. `/etc/pve/firewall/105.fw` : TCP 9696, 8989 et 7878 depuis le LAN. Datacenter éteint. Dossier racine, client et Prowlarr : pas encore branchés.

`curl` et `sqlite3` sont déjà là. Pas d'`apt upgrade`. Pas le script d'installation.

## 1. Compte

```bash
pct exec 105 -- bash -lc 'getent passwd radarr || adduser --system --group --home /var/lib/radarr --shell /usr/sbin/nologin radarr'
pct exec 105 -- bash -lc 'install -d -o radarr -g radarr -m 0750 /var/lib/radarr'
pct exec 105 -- bash -lc 'usermod -aG media radarr && id radarr'
```

`id` contient `media` (1000). Home `/var/lib/radarr`. Avertissement de locale : le compte est créé quand même.

## 2. Écriture

```bash
pct exec 105 -- bash -lc 'runuser -u radarr -- bash -c "umask 0007; touch /mnt/mediatheques/telechargements/complets/.ecriture-radarr"'
ls -l /tank/mediatheques/telechargements/complets/.ecriture-radarr
rm -f /tank/mediatheques/telechargements/complets/.ecriture-radarr
```

Attendu : `-rw-rw----`, groupe `media`. `Permission denied` : s'arrêter, ne pas télécharger Radarr.

## 3. Binaire

Branche `master`. Si `/opt/Radarr` existe déjà : s'arrêter.

```bash
pct exec 105 -- bash -lc 'test ! -e /opt/Radarr'
pct exec 105 -- bash -lc 'curl -fL --retry 3 -o /tmp/Radarr.tar.gz "https://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=x64"'
pct exec 105 -- bash -lc 'gzip -t /tmp/Radarr.tar.gz && echo OK'
pct exec 105 -- bash -lc 'tar -tzf /tmp/Radarr.tar.gz | head'
```

`OK`. Les chemins commencent par `Radarr/`. Un `tar: stdout: write error` vient de `head`. Sinon : s'arrêter, ne pas extraire.

```bash
pct exec 105 -- bash -lc 'tar -xzf /tmp/Radarr.tar.gz -C /opt && chown -R radarr:radarr /opt/Radarr && rm -f /tmp/Radarr.tar.gz'
pct exec 105 -- bash -lc 'ls -ld /opt/Radarr /opt/Radarr/Radarr'
pct exec 105 -- tee /etc/systemd/system/radarr.service >/dev/null << 'EOF'
[Unit]
Description=Radarr Daemon
After=syslog.target network.target

[Service]
User=radarr
Group=radarr
SupplementaryGroups=media
UMask=0007
Type=simple
ExecStart=/opt/Radarr/Radarr -nobrowser -data=/var/lib/radarr/
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
pct exec 105 -- systemctl daemon-reload
pct exec 105 -- systemctl enable --now radarr
pct exec 105 -- systemctl is-active radarr
pct exec 105 -- bash -lc 'curl -sS -o /dev/null -w "%{http_code}\n" --max-time 30 http://127.0.0.1:7878 || true'
```

`active`. Code HTTP `200` ou `302`. Un `000` : attendre dix secondes et relancer le `curl`. Encore `000` : coller `systemctl status radarr` et `journalctl -u radarr -b --no-pager | tail -n 20`.

**28 oct., 18:24.** Compte UID 104, GID 107, groupes `radarr` et `media`. Fichier d'essai `-rw-rw----` `100104 media`, effacé. Archive `101M`, `gzip -t` OK, `tar: stdout: write error` (`head`). Binaire `radarr:radarr`, horodaté 14 sep. 15:54. `is-active` : `active`. `curl` local : `200`. Journal : `Starting Radarr - /opt/Radarr/Radarr - Version 6.4.4.10685`.

## 4. Pare-feu du CT

Les trois ports. Remplacer le fichier.

```bash
cat > /etc/pve/firewall/105.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source <réseau-lan> -p tcp -dport 9696
IN ACCEPT -source <réseau-lan> -p tcp -dport 8989
IN ACCEPT -source <réseau-lan> -p tcp -dport 7878
EOF
```

**Ne pas** activer le pare-feu datacenter.

**28 oct., 18:27.** Fichier réécrit : 9696, 8989 et 7878. Datacenter toujours éteint.

## 5. Interface web

Depuis un poste du LAN : `http://<ip-servarr>:7878`.

Même page que Prowlarr. **Forms**, **Enabled**, mot de passe dans le coffre. **Allowed Hosts** vide.

S'arrêter là. Pas de dossier racine, pas de client, pas de film.

**28 oct., 18:27.** Connecté. Nom du compte non relevé. Mot de passe dans le coffre. Pas de dossier racine, pas de client, pas de film.

## Retour arrière

```bash
pct exec 105 -- systemctl disable --now radarr
pct exec 105 -- rm -rf /opt/Radarr /var/lib/radarr /etc/systemd/system/radarr.service
pct exec 105 -- systemctl daemon-reload
pct exec 105 -- bash -lc 'deluser radarr || true'
```

Remettre `105.fw` avec 9696 et 8989 seulement. Garder `prowlarr`, `sonarr` et le groupe `media`.

---

# Radarr — branchement

**As-built 28 oct., 18:36.** Dossier `/mnt/mediatheques/films`, client qBittorrent catégorie `radarr`, mappage de chemin, application Prowlarr. Les deux **Test** ont réussi. Pas d'indexeur. Pas de film ajouté.

## 1. Dossier et liens

`http://<ip-servarr>:7878` → **Settings** → **Media Management**. **Show Advanced** s'il le faut.

1. **Root Folders** → **Add Root Folder** → `/mnt/mediatheques/films`.
2. **Use Hardlinks instead of Copy** : coché.
3. **Set Permissions** : décoché.

## 2. qBittorrent

**Settings** → **Download Clients**. **Completed Download Handling** → **Enable** coché.

**+** → **qBittorrent**. Garder la catégorie déjà écrite dans le champ. Si le champ est vide : `radarr`. Pas `tv-sonarr` : cette catégorie est celle de Sonarr.

| Champ | Valeur |
|-------|--------|
| Name | `qBittorrent` |
| Host | `<ip-qbittorrent>` |
| Port | `8080` |
| Username | `admin` |
| Password | celui du coffre |
| Category | celle du formulaire, sinon `radarr` |

**Remove Completed** coché. **Post-Import Category** vide. **Use SSL**, **URL Base** et **API Key** vides. **Test**, puis **Save**.

**Remote Path Mappings** → **+**. Les barres finales, comme pour Sonarr.

| Champ | Valeur |
|-------|--------|
| Host | `<ip-qbittorrent>` |
| Remote Path | `/mnt/telechargements/` |
| Local Path | `/mnt/mediatheques/telechargements/` |

## 3. Prowlarr

Dans Prowlarr, **Settings** → **Apps** → **+** → **Radarr**. La clé d'API est dans Radarr → **Settings** → **General** → **Security**. Ne pas la coller ici.

| Champ | Valeur |
|-------|--------|
| Prowlarr Server | `http://<ip-servarr>:9696` |
| Radarr Server | `http://<ip-servarr>:7878` |
| API Key | la clé Radarr |
| Sync Level | Full Sync |

**Test**, puis **Save**. Pas d'indexeur. Pas de film ajouté.

**28 oct., 18:36.** Catégorie `radarr`. Test qBittorrent réussi. Test Prowlarr réussi. Pas d'indexeur.

**28 oct., 18:37.** Film *American History X* ajouté. Chemin `/mnt/mediatheques/films/American History X (1998)`, statut **Downloaded**, 1,9 Gio, profil **Any**. Fichier `American History X (1998).mkv`, x265, AAC 5.1, WEBDL-1080p, anglais. Pas de téléchargement.

---

# Bazarr — décision (28 oct.)

Bazarr s'installe dans le CT **105**. Il écrit les sous-titres à côté des vidéos, donc sur le même montage que Sonarr et Radarr. Pas un nouveau CT. Pas de Docker. Pas dans K3s.

Le compte `bazarr` rejoint `media`. `UMask=0007`, comme Sonarr : un `.srt` créé dans `films/` ou `series/` sort en `0660`, groupe `media`. `Group=bazarr`, `SupplementaryGroups=media`. Jellyfin, déjà dans `media`, pourra lire ces fichiers.

Debian 13 refuse `pip` sur le Python du système (PEP 668). Le wiki propose de renommer le fichier `EXTERNALLY-MANAGED` ou d'ajouter `--break-system-packages`. On ne fait ni l'un ni l'autre. Un environnement à part : `/var/lib/bazarr/venv`. Il est hors de `/opt/bazarr` : une mise à jour de l'application ne l'efface pas. Le service démarre avec le Python de cet environnement, donc une mise à jour ultérieure des dépendances y reste.

`unrar` est dans le dépôt `non-free`. S'il n'a pas de candidat, on continue sans. On n'ajoute pas `non-free` dans ce pas. Les archives les plus courantes sont des zip, que `unzip` ouvre.

Pas de fournisseur de sous-titres dans ce pas. On relie Sonarr et Radarr, on pose un profil Français, on ne lance pas de recherche. Les chemins sont les mêmes des deux côtés (`/mnt/mediatheques/series`, `/mnt/mediatheques/films`) : pas de mappage.

Port **6767**, ajouté à `105.fw` à côté de 9696, 8989 et 7878. Le pare-feu datacenter reste éteint. LAN seulement. Mot de passe dans le coffre.

Pas d'ADR : un service de plus dans le CT déjà tranché. Recyclarr, Lidarr et Navidrome restent ouverts.

---

# Bazarr — procédure

**As-built 29 oct., 10:20.** Bazarr **v1.6.2**, service `active`, `curl` local `200`. Compte `bazarr` UID 105 dans `media`. Sonarr et Radarr : **Test** réussi (`127.0.0.1`, SSL décoché). Profil `français` (langue FR) par défaut des séries et des films ajoutés ensuite. Pas de fournisseur. Pas de recherche. `/etc/pve/firewall/105.fw` : TCP 9696, 8989, 7878 et 6767 depuis le LAN. Datacenter éteint. Mot de passe et clés d'API dans le coffre, pas ici.

Les blocs ci-dessous ont été joués dans l'ordre. Ne pas `zfs destroy`, ne pas `rm` sur `/tank/mediatheques`, ne pas recréer le CT 105. Pas d'`apt upgrade`. Pas de `--break-system-packages`.

## 1. Dépôts

```bash
pct exec 105 -- bash -lc 'python3 --version'
pct exec 105 -- bash -lc 'apt-cache policy python3-venv 7zip ffmpeg unzip unrar'
```

`python3` au moins 3.10. Candidats pour `python3-venv`, `7zip`, `ffmpeg`, `unzip`. `unrar` peut ne pas en avoir : ce n'est pas un arrêt. Un autre paquet sans candidat : s'arrêter.

## 2. Paquets

```bash
pct exec 105 -- bash -lc 'apt-get update && apt-get install -y python3-venv python3-dev python3-pip python3-setuptools unzip ffmpeg 7zip libxml2-dev libxslt1-dev'
pct exec 105 -- bash -lc 'if apt-cache show unrar >/dev/null 2>&1; then apt-get install -y unrar; else echo UNRAR_ABSENT; fi'
```

`UNRAR_ABSENT` : on continue. Ne pas modifier `sources.list`.

**29 oct.** Paquets installés, `ffmpeg` 7:7.1.5-0+deb13u1 en dernier. `apt-cache show unrar` a renvoyé vrai (le paquet est cité, sans candidat) : `apt-get install unrar` s'est arrêté sur `no installation candidate`. Pas de `sources.list`. On continue sans `unrar`.

## 3. Compte et écriture

Le wiki exige un home. Il est `/var/lib/bazarr`. L'avertissement de locale est le même que pour Sonarr : le compte est créé quand même.

```bash
pct exec 105 -- bash -lc 'getent passwd bazarr || adduser --system --group --home /var/lib/bazarr --shell /usr/sbin/nologin bazarr'
pct exec 105 -- bash -lc 'install -d -o bazarr -g bazarr -m 0750 /var/lib/bazarr'
pct exec 105 -- bash -lc 'usermod -aG media bazarr && id bazarr'
pct exec 105 -- bash -lc 'runuser -u bazarr -- bash -c "umask 0007; touch /mnt/mediatheques/telechargements/complets/.ecriture-bazarr"'
ls -l /tank/mediatheques/telechargements/complets/.ecriture-bazarr
rm -f /tank/mediatheques/telechargements/complets/.ecriture-bazarr
```

`id` contient `media` (1000). Fichier d'essai : `-rw-rw----`, groupe `media`. Puis effacé. `Permission denied` : s'arrêter.

**29 oct., 10:07.** Avertissement de locale, compte créé. UID 105, GID 108, groupes `bazarr` et `media` (1000). Fichier d'essai `-rw-rw----` `100105 media`, effacé.

## 4. Application et environnement

L'archive vient de la release GitHub `latest`. Si `/opt/bazarr` existe déjà : s'arrêter.

```bash
pct exec 105 -- bash -lc 'test ! -e /opt/bazarr'
pct exec 105 -- bash -lc 'curl -fL --retry 3 -o /tmp/bazarr.zip https://github.com/morpheus65535/bazarr/releases/latest/download/bazarr.zip'
pct exec 105 -- bash -lc 'unzip -l /tmp/bazarr.zip | head'
```

`bazarr.py` apparaît sans dossier devant. Si tous les chemins commencent par `bazarr/` : s'arrêter, ne pas extraire. `head` ne suffit pas : l'archive liste d'abord le dossier `bazarr/`. Vérifier avec `unzip -l | grep -E "bazarr\.py|requirements\.txt"`.

```bash
pct exec 105 -- bash -lc 'unzip -q /tmp/bazarr.zip -d /opt/bazarr && rm -f /tmp/bazarr.zip'
pct exec 105 -- bash -lc 'test -f /opt/bazarr/bazarr.py && test -f /opt/bazarr/requirements.txt'
pct exec 105 -- bash -lc 'runuser -u bazarr -- python3 -m venv /var/lib/bazarr/venv'
pct exec 105 -- bash -lc 'chown -R bazarr:bazarr /opt/bazarr'
pct exec 105 -- bash -lc 'runuser -u bazarr -- /var/lib/bazarr/venv/bin/pip install -r /opt/bazarr/requirements.txt'
```

Le `pip` peut être long. Une erreur : coller les vingt dernières lignes. Ne pas relancer avec `--break-system-packages`.

**29 oct., 10:08.** Archive 29,5 Mio, fichiers datés du 26 sep. 01:37. `bazarr.py` et `requirements.txt` à la racine, à côté du dossier `bazarr/`. `pywin32` ignoré (marqueur Windows). Installés : Pillow 13.0.0, lxml 6.1.3, numpy 2.3.5, setuptools 84.2.1, webrtcvad-wheels 2.0.14.post1.

## 5. Service

Pas le `sleep 30` du wiki. Sonarr et Radarr sont sur le même CT ; Bazarr se reconnecte s'ils démarrent après.

```bash
pct exec 105 -- tee /etc/systemd/system/bazarr.service >/dev/null << 'EOF'
[Unit]
Description=Bazarr Daemon
After=network.target sonarr.service radarr.service

[Service]
WorkingDirectory=/opt/bazarr
User=bazarr
Group=bazarr
SupplementaryGroups=media
UMask=0007
Type=simple
ExecStart=/var/lib/bazarr/venv/bin/python /opt/bazarr/bazarr.py
KillSignal=SIGINT
TimeoutStopSec=20
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
pct exec 105 -- systemctl daemon-reload
pct exec 105 -- systemctl enable --now bazarr
pct exec 105 -- systemctl is-active bazarr
pct exec 105 -- bash -lc 'curl -sS -o /dev/null -w "%{http_code}\n" --max-time 30 http://127.0.0.1:6767 || true'
```

`active`. Code HTTP `200` ou `302`. Un `000` : attendre dix secondes et relancer le `curl`. Encore `000` : coller `systemctl status bazarr` et `journalctl -u bazarr -b --no-pager | tail -n 30`.

La version. Le journal ne contient pas le mot « version » : elle est dans le fichier.

```bash
pct exec 105 -- bash -lc 'cat /opt/bazarr/VERSION'
```

**29 oct., 10:11.** `active`. `curl` local : `200`. Fichier `VERSION` : `v1.6.2`. Journal (UTC) : `BAZARR is started and waiting for requests` sur le port 6767.

## 6. Pare-feu du CT

Les quatre ports. Remplacer le fichier.

```bash
cat > /etc/pve/firewall/105.fw << 'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
IN ACCEPT -source <réseau-lan> -p tcp -dport 9696
IN ACCEPT -source <réseau-lan> -p tcp -dport 8989
IN ACCEPT -source <réseau-lan> -p tcp -dport 7878
IN ACCEPT -source <réseau-lan> -p tcp -dport 6767
EOF
```

**Ne pas** activer le pare-feu datacenter.

**29 oct., 10:12.** Fichier réécrit : 9696, 8989, 7878 et 6767. Datacenter toujours éteint.

## 7. Compte, Sonarr, Radarr

Depuis un poste du LAN : `http://<ip-servarr>:6767`.

**Settings → General → Security**. Authentication : **Form**. Un identifiant, un mot de passe dans le coffre. Ne pas le coller ici. **Save**, puis se reconnecter.

**Settings → Sonarr**.

| Champ | Valeur |
|-------|--------|
| Hostname | `127.0.0.1` |
| Port | `8989` |
| SSL | décoché |
| API Key | la clé Sonarr (Settings → General → Security) |

**Test**, puis **Save**.

**Settings → Radarr**. Même chose, port `7878`, clé Radarr.

**Test**, puis **Save**. Pas de mappage de chemin : les dossiers sont déjà `/mnt/mediatheques/series` et `/mnt/mediatheques/films` des deux côtés.

**Settings → Languages**. Ajouter un profil nommé `Français`, langue French. Le poser comme profil par défaut des séries et des films. Pas de fournisseur. Pas de bouton **Search**.

S'arrêter. Coller la version et dire si les deux tests ont réussi.

**29 oct., 10:20.** Connecté. Nom du compte non relevé. Mot de passe dans le coffre. Sonarr activé, `127.0.0.1:8989`, SSL décoché, base `/` : le test affiche **4.0.20.3014**. Radarr activé, `127.0.0.1:7878`, SSL décoché : le test affiche **6.4.4.10685**. Pas de mappage. Séries et Films : **LIVE**. Profil `français`, langue FR, profil par défaut des séries et des films ajoutés après coup. La sélection par tag est activée pour les séries seulement (tag `FR`). Pas de fournisseur. Pas de recherche. Les clés d'API ne sont pas recopiées ici.

**29 oct., 10:25.** Clés Sonarr et Radarr régénérées, puis recollées dans Bazarr et dans Prowlarr. Tests déclarés bons. Les anciennes clés ne sont plus celles en service. Valeurs absentes de ce fichier.

## Retour arrière

```bash
pct exec 105 -- systemctl disable --now bazarr || true
pct exec 105 -- rm -rf /opt/bazarr /var/lib/bazarr /etc/systemd/system/bazarr.service
pct exec 105 -- systemctl daemon-reload
pct exec 105 -- bash -lc 'deluser bazarr || true'
```

Remettre `105.fw` avec 9696, 8989 et 7878 seulement. Garder `prowlarr`, `sonarr`, `radarr` et le groupe `media`.

---

# Indexeur — Knaben (29 oct.)

Un seul indexeur. **Knaben**, méta-moteur torrent public, sans compte. Pas de FlareSolverr. Prowlarr l'interroge depuis la box. Le téléchargement, s'il a lieu, part du compte qBittorrent, donc par Mullvad.

**29 oct., 10:30.** **Test** Knaben réussi dans Prowlarr. L'indexeur apparaît dans Sonarr et dans Radarr (**Settings → Indexers**), poussé par le Full Sync.

**29 oct., 10:35.** Sonarr envoie l'épisode 1 de la saison 3 de *Preacher*. Catégorie qBittorrent `tv-sonarr`. La release n'a pas de seed : rien n'arrive dans `complets/`.

**29 oct., 10:38.** Essai EZTV. **Test** en échec : `Name or service not known (eztvx.to:443)`. Le nom ne se résout pas. Le texte DNS/SSL de Prowlarr est le message générique. Indexeur non gardé. Pas de FlareSolverr.

**29 oct., 10:45.** D'autres indexeurs ont été ajoutés (noms non relevés). Un grab *Preacher* S03E01 part en catégorie `tv-sonarr`. qBittorrent : taille 0 o, statut **Downloading metadata**, seeds `0 (0)`, pairs `0 (2)`. La plupart des trackers : **Not working** (`Host not found`, `certificate verify failed`, `timed out`, `Connection refused`, `No route to host`). Trois trackers **Working**, chacun avec 1 seed. Le tunnel joint ces trackers. Le swarm vivant n'a qu'un seed, et aucune connexion de pair n'aboutit : les métadonnées n'arrivent pas. L'image Debian du 28 oct. avait fini sans redirection de port, sur un swarm beaucoup plus gros. Mullvad n'a pas de transfert de port dans ce montage.

**29 oct., 10:48.** Deuxième grab, autre indexeur. Nom de fichier présent, 852,7 Mio, catégorie `tv-sonarr`, statut **Stalled**, seeds `0 (0)`, pairs `0 (2)`. Plusieurs trackers **Working** avec 1 ou 2 seeds. Les métadonnées sont là. Aucun pair ne se connecte.

**29 oct., 10:57.** Cinq grabs en parallèle, catégorie `tv-sonarr`. Tous en **Downloading metadata**, taille 0 o, seeds `0 (0)`, pairs `0 (2)` ou `0 (3)`. Le client ne reçoit que deux ou trois adresses et n'en connecte aucune. Le décompte du site (jusqu'à 1031 seeds) n'apparaît pas dans qBittorrent. Pas d'indexeur de plus.

---

# Proton — décision (29 oct.)

Le VPN du CT **104** passe sur le compte **Proton VPN** déjà ouvert. qBittorrent, Sonarr et Radarr restent sur `<ip-qbittorrent>`. Le PC, la tablette et Android utilisent l'application Proton : ils ne sont pas dans ces blocs. Bridge non plus.

Proton n'ouvre pas un port fixe. Le tunnel demande un bail de 60 secondes à `10.2.0.1`, et le même numéro tant que le tunnel tient. Un service sous le compte `qbittorrent` le redemande toutes les 45 secondes et, si le numéro change, le pose dans qBittorrent. S'il s'arrête, les pairs entrants perdent le port au bout d'une minute.

Le kill switch ne change pas de principe : uid `qbittorrent`, table `51820`, nftables. Le résolveur change. Mullvad utilise `10.64.0.1`. Le fichier WireGuard de Proton annonce `10.2.0.1`, qui est aussi la passerelle du port. Le port n'est pas ouvert sur la box. qBittorrent continue d'écouter sur `wg0` seulement.

La clé Mullvad en service est copiée (`wg0.conf.mullvad`) avant l'échange. On ne la révoque pas dans ces blocs.

Pas d'ADR. Pas de second client torrent.

---

# Proton — procédure

**Jouée le 29 oct.** Blocs **dans l'ordre**. En cas d'erreur : coller la sortie. Ne pas `zfs destroy`, ne pas `rm` sur `/tank/mediatheques`, ne pas ouvrir le port sur la box, ne pas coller la clé privée ni un mot de passe.

## 0. Fichier WireGuard

Compte Proton VPN → téléchargements → configuration **WireGuard**.

| Champ | Valeur |
|-------|--------|
| Nom | `qbittorrent` |
| Plateforme | celle qui produit un `.conf` (`Linux` ou `Router`, selon la page) |
| Options | **NAT-PMP** coché. Pas de NAT modéré en même temps |
| Serveur | **un** serveur marqué P2P (double flèche) |

Un seul `.conf`. Il contient `[Interface]` et `PrivateKey`. Ne pas l'ouvrir dans le dépôt, ne pas le commiter, ne pas coller la clé.

Sur le PC, la ligne DNS seulement :

```powershell
Select-String -Path "$env:USERPROFILE\Downloads\NOM-DU-FICHIER.conf" -Pattern '^DNS'
```

Attendu : `10.2.0.1` dans la ligne. Proton y ajoute son résolveur IPv6. Le script retire toute la ligne `DNS`. Sans `10.2.0.1` : s'arrêter et coller cette ligne, pas la clé. Constat du 29 oct. : `DNS = 10.2.0.1, 2a07:b944::2:1`, fichier `qbittorrent-FR-506.conf`.

## 1. Constat (sur `pve`, root)

```bash
pct exec 104 -- systemctl is-active wg-quick@wg0 qbittorrent-nox@qbittorrent
pct exec 104 -- cat /etc/resolv.conf
pct exec 104 -- grep -n '10.64.0.1' /etc/nftables.conf /usr/local/sbin/ajuster-wg0.py
pct exec 104 -- wg show | sed -n '1,8p'
pct exec 104 -- bash -lc 'apt-cache policy natpmpc'
```

Attendu : les deux services `active`, `10.64.0.1` dans nftables, une poignée de main WireGuard. Coller `resolv.conf`, le `grep` et la version de `natpmpc`. Pas de candidat pour `natpmpc` : s'arrêter. Une version `20150609` : s'arrêter, elle lit mal la réponse.

**29 oct.** Les deux services `active`. `resolv.conf` : `nameserver 10.64.0.1`. nftables : les deux dnat. `natpmpc` non installé, candidat `20230423-1.2+b3`. Le script ne contient pas `10.64.0.1` : la route et `FwMark = 51820` sont dans `wg0.conf` seulement.

## 2. Garder Mullvad, poser Proton

```bash
pct exec 104 -- systemctl stop qbittorrent-nox@qbittorrent
pct exec 104 -- systemctl stop wg-quick@wg0
pct exec 104 -- cp -a /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.mullvad
pct exec 104 -- chmod 600 /etc/wireguard/wg0.conf.mullvad
pct exec 104 -- wc -c /etc/wireguard/wg0.conf.mullvad
```

Taille non nulle. Puis le fichier Proton :

```powershell
scp "$env:USERPROFILE\Downloads\NOM-DU-FICHIER.conf" root@<ip-pve>:/root/wg0.conf
```

Sur `pve` :

```bash
pct push 104 /root/wg0.conf /etc/wireguard/wg0.conf
rm -f /root/wg0.conf
pct exec 104 -- chown root:root /etc/wireguard/wg0.conf
pct exec 104 -- chmod 600 /etc/wireguard/wg0.conf
```

Effacer le `.conf` dans `Downloads`. Il reste `wg0.conf` (Proton) et `wg0.conf.mullvad`.

## 3. DNS

Le script retire chaque `PostUp` et ne réécrit que les règles d'uid. La route `10.64.0.1/32` et `FwMark = 51820` sont dans `wg0.conf`. Sans la marque, nftables jette la poignée de main. Sans la route, `10.2.0.1` ne passe pas par `wg0`. On les ajoute au script, vers `10.2.0.1`, puis on le relance.

```bash
pct exec 104 -- python3 - << 'PY'
from pathlib import Path
p = Path("/usr/local/sbin/ajuster-wg0.py")
text = p.read_text()
old = 'if line.startswith(("DNS = ", "Table = ", "PostUp = ", "PreDown = ")):'
new = 'if line.startswith(("DNS = ", "Table = ", "FwMark = ", "PostUp = ", "PreDown = ")):'
if old not in text:
    raise SystemExit("debut introuvable")
if "FwMark = 51820" in text or "10.2.0.1" in text:
    raise SystemExit("deja modifie")
text = text.replace(old, new, 1)
needle = '    "Table = 51820",\n'
insert = '    "Table = 51820",\n    "FwMark = 51820",\n'
if needle not in text:
    raise SystemExit("Table introuvable")
text = text.replace(needle, insert, 1)
needle = '    "PreDown = ip rule del to <réseau-lan> lookup main priority 100 || true",\n]'
insert = '''    "PreDown = ip rule del to <réseau-lan> lookup main priority 100 || true",
    "PostUp = ip route replace 10.2.0.1/32 dev wg0",
    "PreDown = ip route del 10.2.0.1/32 dev wg0 || true",
]'''
if needle not in text:
    raise SystemExit("fin extra introuvable")
text = text.replace(needle, insert, 1)
p.write_text(text)
print("ok")
PY
pct exec 104 -- grep -n 'FwMark\|10.2.0.1' /usr/local/sbin/ajuster-wg0.py
pct exec 104 -- sed -i 's/10\.64\.0\.1/10.2.0.1/g' /etc/nftables.conf
pct exec 104 -- python3 /usr/local/sbin/ajuster-wg0.py
pct exec 104 -- systemctl restart nftables
pct exec 104 -- nft list table inet torrent
```

Le `grep` montre `FwMark` et les deux lignes de route. La sortie du script a `PrivateKey = [présent]`, `FwMark = 51820` et `10.2.0.1`. Pas de `10.64.0.1`. Le dnat vise `10.2.0.1`.

Si le constat montrait `nameserver 10.64.0.1` :

```bash
pct exec 104 -- sed -i 's/10\.64\.0\.1/10.2.0.1/' /etc/resolv.conf
pct exec 104 -- cat /etc/resolv.conf
```

Si le constat montrait `<ip-box>` : ne pas toucher `resolv.conf`.

**29 oct.** Script patché (`FwMark`, route `10.2.0.1`). Fichier réécrit : `Address = 10.2.0.2/32`, pair `FR#506`, `Endpoint = <ip-serveur-vpn>:51820`. nftables : dnat vers `10.2.0.1`, marque `0xca6c`. `resolv.conf` : `nameserver 10.2.0.1`. Tunnel pas encore relancé.

## 4. Tunnel, puis coupure

```bash
pct exec 104 -- systemctl start wg-quick@wg0
pct exec 104 -- wg show
pct exec 104 -- ip route show table 51820
pct exec 104 -- ip route show 10.2.0.1
pct exec 104 -- runuser -u qbittorrent -- curl -4 -fsS --max-time 20 https://api.ipify.org
echo
pct exec 104 -- curl -4 -fsS --max-time 20 https://api.ipify.org
echo
```

Poignée de main récente. Table `51820` : `default dev wg0`. Route `10.2.0.1` via `wg0`. Les deux IP diffèrent. La première est Proton. La seconde est la box. Même adresse : s'arrêter, ne pas lancer qBittorrent.

**29 oct.** Tunnel levé. Poignée de main, `fwmark: 0xca6c`, `default dev wg0`, `10.2.0.1 dev wg0`. Compte `<ip-sortie-vpn>`, root une autre adresse. Coupure pas encore jouée.

Coupure :

```bash
pct exec 104 -- systemctl stop wg-quick@wg0
pct exec 104 -- runuser -u qbittorrent -- curl -4 --max-time 10 -o /dev/null -w '%{http_code}\n' http://1.1.1.1 || true
pct exec 104 -- curl -4 --max-time 10 -o /dev/null -s -w '%{http_code}\n' http://1.1.1.1
```

Attendu pour le compte : `000`. Attendu pour root : `301`. Un `301` ou `200` pour le compte : remettre Mullvad (retour arrière) et s'arrêter.

**29 oct.** Coupure jouée. Compte : `000`. Root : `301`.

```bash
pct exec 104 -- systemctl start wg-quick@wg0
pct exec 104 -- systemctl start qbittorrent-nox@qbittorrent
pct exec 104 -- systemctl is-active wg-quick@wg0 qbittorrent-nox@qbittorrent
```

Les deux `active`.

## 5. Le mot de passe web, hors du script

Le service lit le mot de passe de l'interface qBittorrent (`admin`, celui du coffre). Une ligne, sans retour chariot. Ne pas la recoller.

```bash
pct enter 104
install -o qbittorrent -g qbittorrent -m 0600 /dev/null /var/lib/qbittorrent/web.pass
printf '%s' 'MOT_DU_COFFRE' > /var/lib/qbittorrent/web.pass
chown qbittorrent:qbittorrent /var/lib/qbittorrent/web.pass
chmod 600 /var/lib/qbittorrent/web.pass
exit
```

Dans l'interface `http://<ip-qbittorrent>:8080`, **Connection** : noter le port d'écoute actuel (coffre, retour arrière). Décocher le port aléatoire. **Use UPnP / NAT-PMP** reste décoché. **Advanced** → interface : `wg0`, inchangée.

**29 oct.** Tunnel et qBittorrent `active`. Fichier `web.pass` posé. Port d'écoute noté pour le retour arrière : `25337`.

## 6. Natpmpc, une fois

```bash
pct exec 104 -- bash -lc 'apt install -y natpmpc'
pct exec 104 -- runuser -u qbittorrent -- natpmpc -g 10.2.0.1
pct exec 104 -- runuser -u qbittorrent -- natpmpc -a 1 0 udp 60 -g 10.2.0.1
pct exec 104 -- runuser -u qbittorrent -- natpmpc -a 1 0 tcp 60 -g 10.2.0.1
```

La première commande affiche une adresse publique. Les deux suivantes annoncent le **même** port public. Deux ports différents : s'arrêter. Ce bail meurt en 60 secondes : enchaîner le bloc 7 tout de suite.

## 7. Le service qui renouvelle

```bash
pct exec 104 -- tee /usr/local/sbin/proton-port >/dev/null << 'EOF'
#!/bin/sh
set -eu
gw=10.2.0.1
api=http://<ip-qbittorrent>:8080
passfile=/var/lib/qbittorrent/web.pass
state=/var/lib/qbittorrent/proton-port.last
cookie=$(mktemp)
trap 'rm -f "$cookie"' EXIT
login() {
  curl -fsS -c "$cookie" --max-time 10 \
    -H "Referer: ${api}/" \
    --data-urlencode "username=admin" \
    --data-urlencode "password@${passfile}" \
    "$api/api/v2/auth/login" >/dev/null
}
while true; do
  out=$(natpmpc -a 1 0 udp 60 -g "$gw" && natpmpc -a 1 0 tcp 60 -g "$gw") || {
    echo "natpmpc en erreur" >&2
    sleep 10
    continue
  }
  port=$(printf '%s\n' "$out" | sed -n 's/.*public port \([0-9][0-9]*\).*/\1/p' | head -n 1)
  prev=
  [ -f "$state" ] && prev=$(cat "$state")
  if [ -n "$port" ] && [ "$port" != "$prev" ]; then
    login
    curl -fsS -b "$cookie" --max-time 10 \
      -H "Referer: ${api}/" \
      --data-urlencode "json={\"listen_port\":${port}}" \
      "$api/api/v2/app/setPreferences"
    printf '%s\n' "$port" > "$state"
    echo "port $port"
  fi
  sleep 45
done
EOF
pct exec 104 -- chmod 755 /usr/local/sbin/proton-port
pct exec 104 -- tee /etc/systemd/system/proton-port.service >/dev/null << 'EOF'
[Unit]
After=wg-quick@wg0.service qbittorrent-nox@qbittorrent.service
BindsTo=wg-quick@wg0.service

[Service]
User=qbittorrent
Group=qbittorrent
ExecStart=/usr/local/sbin/proton-port
Restart=on-failure
RestartSec=5
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
pct exec 104 -- systemctl daemon-reload
pct exec 104 -- systemctl enable --now proton-port
pct exec 104 -- systemctl is-active proton-port
pct exec 104 -- journalctl -u proton-port -n 20 --no-pager
```

`active`. Le journal affiche `port` et un numéro, le même que le bloc 6. Pas de mot de passe dans ces lignes. L'interface qBittorrent, **Connection**, montre ce numéro.

**29 oct., 17:35.** `proton-port` `active`. Journal : `port 64509`. L'ancien port d'écoute était `25337`.

## 8. Le port répond

```bash
pct exec 104 -- runuser -u qbittorrent -- curl -4 -fsS --max-time 20 https://api.ipify.org
echo
```

Depuis le PC, avec cette adresse et le numéro du journal :

```powershell
Test-NetConnection -ComputerName ADRESSE -Port NUMERO
```

`TcpTestSucceeded : True`. `False` : coller, s'arrêter.

**29 oct., 18:37.** Depuis le PC, vers `<ip-sortie-vpn>:64509`. Sortie par l'interface Proton du PC (`10.2.0.2`). `TcpTestSucceeded : True`.

Les grabs déjà dans qBittorrent restent. On n'en ajoute pas. Au bout de quelques minutes, un pair connecté, ou le bloc 8 seul s'il reste à 0 pair : le port est ouvert, le swarm peut être vide.

Critère : IP différente de la box, coupure à `000`, `TcpTestSucceeded : True`, le service encore `active` après une minute.

## Retour arrière

```bash
pct exec 104 -- systemctl disable --now proton-port
pct exec 104 -- systemctl stop qbittorrent-nox@qbittorrent
pct exec 104 -- systemctl stop wg-quick@wg0
pct exec 104 -- cp -a /etc/wireguard/wg0.conf.mullvad /etc/wireguard/wg0.conf
pct exec 104 -- chmod 600 /etc/wireguard/wg0.conf
pct exec 104 -- sed -i 's/10\.2\.0\.1/10.64.0.1/g' /usr/local/sbin/ajuster-wg0.py /etc/nftables.conf /etc/resolv.conf
pct exec 104 -- systemctl restart nftables
pct exec 104 -- systemctl start wg-quick@wg0
pct exec 104 -- runuser -u qbittorrent -- curl -4 -fsS --max-time 20 https://am.i.mullvad.net/json
pct exec 104 -- systemctl start qbittorrent-nox@qbittorrent
```

`"mullvad_exit_ip": true` pour le compte. Dans qBittorrent, remettre le port noté au bloc 5. Effacer `/var/lib/qbittorrent/web.pass` et `proton-port.last`. `wg0.conf.mullvad` reste tant que Proton n'est pas tenu pour bon. La clé Mullvad du CT ne se révoque pas ici.

---

# Recyclarr — décision (29 oct.)

Recyclarr s'installe dans le CT **105**, en binaire, compte `recyclarr`. Pas de Docker. Pas dans K3s. Pas de port : il n'a pas d'interface. Il appelle Sonarr (`127.0.0.1:8989`) et Radarr (`127.0.0.1:7878`) avec les clés déjà au coffre. Il ne rejoint pas `media` : il n'écrit pas dans la médiathèque.

Le profil ajouté est le guide français **MULTi.VO** en HD (piste d'origine plus une piste française). Ça va avec Jellyfin réglé en VO et sous-titres français, et avec le profil Bazarr `français`. Pas le profil VF (doublage à la place de la VO). Pas le 4K.

On ne pose pas `quality_definition`. Sur Sonarr 4, ces tailles sont globales et changeraient aussi le profil **Any**. On ne met pas `delete_old_custom_formats` : le premier passage ne retire pas des formats qu'il n'a pas créés.

Recyclarr crée le profil. Il ne l'assigne pas. *Cold Case* et *American History X* restent sur **Any**. Pas de recherche. Pas de timer dans ce pas : une synchro manuelle, une fois.

Pas d'ADR : un outil de plus dans le CT déjà tranché. Lidarr et Navidrome restent ouverts.

---

# Recyclarr — procédure

**Jouée le 1er nov.** Recyclarr **v8.8.1**, compte `recyclarr` uid 106. Profils `[French MULTi.VO] HD Bluray + WEB` créés dans Sonarr (57 formats) et Radarr (58 formats). *Cold Case* et *American History X* restent sur **Any**. Pas de recherche. Pas de timer. Les blocs ci-dessous ont été joués dans l'ordre. Ne pas `zfs destroy`, ne pas `rm` sur `/tank/mediatheques`, ne pas coller une clé d'API.

## 1. Constat (sur `pve`, root)

```bash
pct exec 105 -- systemctl is-active sonarr radarr
pct exec 105 -- bash -lc 'apt-cache policy git wget xz-utils ca-certificates'
pct exec 105 -- bash -lc 'test ! -e /usr/local/bin/recyclarr && echo ABSENT'
pct exec 105 -- bash -lc 'getent passwd recyclarr || echo PAS_DE_COMPTE'
```

Attendu : les deux services `active`, un candidat pour chaque paquet, `ABSENT`, `PAS_DE_COMPTE`. Autre chose : s'arrêter.

**1er nov.** Sonarr et Radarr `active`. `git` non installé, candidat `1:2.47.3-0+deb13u1`. `wget` et `ca-certificates` déjà au candidat. `xz-utils` installé en `5.8.1-1`, candidat `5.8.1-1+deb13u2`. Binaire absent. Pas de compte `recyclarr`.

## 2. Compte et paquets

```bash
pct exec 105 -- bash -lc 'apt-get update && apt-get install -y git wget xz-utils ca-certificates'
pct exec 105 -- bash -lc 'getent passwd recyclarr || adduser --system --group --home /var/lib/recyclarr --shell /usr/sbin/nologin recyclarr'
pct exec 105 -- bash -lc 'install -d -o recyclarr -g recyclarr -m 0750 /var/lib/recyclarr /var/lib/recyclarr/.config /var/lib/recyclarr/.config/recyclarr'
pct exec 105 -- bash -lc 'id recyclarr'
```

`adduser` peut prévenir que `LANG=en_US.UTF-8` manque : le compte est créé quand même. Home `/var/lib/recyclarr`. Le groupe `media` n'y est pas. Pas d'`apt upgrade`.

**1er nov.** `id` : `uid=106(recyclarr) gid=109(recyclarr) groups=109(recyclarr)`. Pas de groupe `media`.

## 3. Binaire v8.8.1

```bash
pct exec 105 -- bash -lc 'curl -fL --retry 3 -o /tmp/recyclarr.tar.xz https://github.com/recyclarr/recyclarr/releases/download/v8.8.1/recyclarr-linux-x64.tar.xz'
pct exec 105 -- bash -lc 'tar -tJf /tmp/recyclarr.tar.xz'
```

`curl` en erreur, ou un dossier dans la liste : s'arrêter, ne pas extraire. Des fichiers à côté du binaire : n'extraire que `recyclarr`.

**1er nov.** Liste : `recyclarr`, `Recyclarr.Api.Radarr.xml`, `Recyclarr.Api.Sonarr.xml`, `Recyclarr.Core.xml`, `recyclarr.xml`. Pas de dossier.

```bash
pct exec 105 -- bash -lc 'tar -xJf /tmp/recyclarr.tar.xz -C /usr/local/bin recyclarr && chmod 755 /usr/local/bin/recyclarr && rm -f /tmp/recyclarr.tar.xz'
pct exec 105 -- runuser -u recyclarr -- /usr/local/bin/recyclarr --version
```

La version affichée est `8.8.1`. Les commandes suivantes gardent ce chemin : sans lui, `runuser` ne trouve pas le binaire.

**1er nov.** Binaire `43318628` octets, `root:root`, `755`. `/usr/local/bin/recyclarr --version` : `v8.8.1`. Le même chemin sous `runuser` aussi.

## 4. Clés, hors du dépôt

Les clés sont celles du coffre (Sonarr et Radarr → **Settings** → **General** → **Security**). Une ligne chacune. Ne pas les recoller.

```bash
pct enter 105
install -o recyclarr -g recyclarr -m 0600 /dev/null /var/lib/recyclarr/.config/recyclarr/secrets.yml
cat > /var/lib/recyclarr/.config/recyclarr/secrets.yml << 'EOF'
sonarr_url: http://127.0.0.1:8989
sonarr_apikey: "CLE_SONARR"
radarr_url: http://127.0.0.1:7878
radarr_apikey: "CLE_RADARR"
EOF
chown recyclarr:recyclarr /var/lib/recyclarr/.config/recyclarr/secrets.yml
chmod 600 /var/lib/recyclarr/.config/recyclarr/secrets.yml
exit
```

**1er nov.** `secrets.yml` : `600 recyclarr:recyclarr`. Les textes `CLE_` ne sont plus dans le fichier. Clés non recopiées ici.

## 5. Choisir le profil, sans synchro

La première commande télécharge le guide. Elle peut prendre une minute.

```bash
pct exec 105 -- runuser -u recyclarr -- /usr/local/bin/recyclarr list quality-profiles sonarr --filter 'MULTi.VO'
pct exec 105 -- runuser -u recyclarr -- /usr/local/bin/recyclarr list quality-profiles radarr --filter 'MULTi.VO'
```

Pour chaque appli, une seule ligne dont le nom contient `MULTi.VO` et `HD Bluray + WEB`, et pas `UHD`. Zéro ligne, ou plusieurs : s'arrêter et coller la liste. Noter les deux `trash_id`. Ne pas lancer `sync`.

**1er nov.** Sonarr : `[French MULTi.VO] HD Bluray + WEB (1080p)`, `4c48f506c1116a3a57ae33f12346bd15`. Radarr : `[French MULTi.VO] HD Bluray + WEB`, `2572ce3ea4eef1c19d59e0e20ed1cea7`. Les lignes UHD et Remux ne sont pas prises.

## 6. Fichier

Remplacer les deux identifiants par ceux du bloc 5. Rien d'autre.

```bash
pct exec 105 -- tee /var/lib/recyclarr/.config/recyclarr/recyclarr.yml >/dev/null << 'EOF'
sonarr:
  sonarr-multi-vo:
    base_url: !secret sonarr_url
    api_key: !secret sonarr_apikey
    delete_old_custom_formats: false
    quality_profiles:
      - trash_id: 4c48f506c1116a3a57ae33f12346bd15
        reset_unmatched_scores:
          enabled: true

radarr:
  radarr-multi-vo:
    base_url: !secret radarr_url
    api_key: !secret radarr_apikey
    delete_old_custom_formats: false
    quality_profiles:
      - trash_id: 2572ce3ea4eef1c19d59e0e20ed1cea7
        reset_unmatched_scores:
          enabled: true
EOF
pct exec 105 -- chown recyclarr:recyclarr /var/lib/recyclarr/.config/recyclarr/recyclarr.yml
pct exec 105 -- chmod 600 /var/lib/recyclarr/.config/recyclarr/recyclarr.yml
```

Pas de clé dans ce fichier. Pas de bloc `quality_definition`.

**1er nov.** `recyclarr.yml` : `600 recyclarr:recyclarr`. Sonarr `4c48f506c1116a3a57ae33f12346bd15`, Radarr `2572ce3ea4eef1c19d59e0e20ed1cea7`. Clés en `!secret`. Pas de `quality_definition`. Synchro pas encore lancée.

## 7. Synchro, une fois

Dans Sonarr et Radarr, avant la commande : *Cold Case* et *American History X* sont sur **Any**. La file d'attente n'a pas de mise à niveau lancée pour eux.

Les noms d'instance sont uniques dans tout le fichier. `multi-vo` des deux côtés est refusé.

**1er nov.** Premier `sync` : `Duplicate Instances` / `multi-vo`. Rien n'a été écrit dans Sonarr ni Radarr. Noms séparés ensuite.

```bash
pct exec 105 -- runuser -u recyclarr -- /usr/local/bin/recyclarr sync
```

Le journal crée un profil dont le nom contient `MULTi.VO`. Il ne parle pas du profil **Any**. S'il le modifie : s'arrêter, coller, ne pas sauvegarder ailleurs.

**1er nov.** Deuxième `sync` : `sonarr-multi-vo` 57 formats et 1 profil, `radarr-multi-vo` 58 formats et 1 profil. Tailles, nommage et gestion des médias : `--`. Interface confirmée : profil MULTi.VO présent des deux côtés, *Cold Case* et *American History X* sur **Any**, file sans recherche nouvelle. Profil non assigné.

Ensuite, dans les deux interfaces : le nouveau profil est là. *Cold Case* et *American History X* sont encore sur **Any**. La file n'a pas de recherche nouvelle. On n'assigne pas le profil. On ne clique pas **Search**.

## Retour arrière

Si une série ou un film a été passé sur le profil MULTi.VO, le remettre sur **Any** avant de supprimer le profil. Puis supprimer ce profil dans Sonarr et dans Radarr. Il n'est utilisé par aucun titre.

```bash
pct exec 105 -- rm -f /usr/local/bin/recyclarr
pct exec 105 -- deluser --remove-home recyclarr
```

`deluser` retire `/var/lib/recyclarr`, donc `secrets.yml` avec. Les clés restent au coffre. Sonarr, Radarr et le profil **Any** restent.

---

# Ensuite

1. Recyclarr v8.8.1 est en service sur le CT 105 (1er nov.). Profils MULTi.VO créés, non assignés. Les titres déjà importés restent sur **Any**.
2. Proton VPN est en service sur le CT 104. `wg0.conf.mullvad` reste. La clé Mullvad du CT ne se révoque pas ici.
3. SMB `Mediatheques` seulement si l'Explorateur doit écrire ici : idmap du CT 102 à étendre, sans casser `perso`.
