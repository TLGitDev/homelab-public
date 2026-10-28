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

**En cours (28 oct.).** CT **103** `jellyfin`, `<ip-jellyfin>`, **running**. Paquet **12.4+deb13**, service `active`, `/health` = `Healthy`. Le compte `jellyfin` (UID 102) est dans `media` et liste `/mnt/mediatheques/films`. Reste : règle pare-feu du CT, assistant web, un fichier lu.

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

Lecture VO + sous-titres FR : réglage du **compte**, pas de la bibliothèque. Menu utilisateur → Paramètres → Lecture. Langue audio : pas le français (piste par défaut / originale). Sous-titres : Français. Mode : Toujours. « Intelligent » ne suffit pas si une piste VF existe et que l'audio préféré est le français : Jellyfin choisirait le doublage.

## Retour arrière

Le montage `mp0` ne contient pas une copie. Détruire le CT ne touche pas à `tank/mediatheques`.

```bash
pct stop 103
pct destroy 103
```

Retirer `root:987:1` de `/etc/subgid` seulement si plus aucun CT ne l'utilise. Garder le groupe hôte `media` et les `chgrp` déjà faits. Effacer `/etc/pve/firewall/103.fw` s'il reste.

---

# Ensuite

1. Règle pare-feu du CT 103, assistant web, un fichier lu depuis le LAN.
2. qBittorrent isolé, chemins `telechargements/incomplets` et `complets`, même dataset.
3. SMB `Mediatheques` seulement si l'Explorateur doit écrire ici : idmap du CT 102 à étendre, sans casser `perso`.
