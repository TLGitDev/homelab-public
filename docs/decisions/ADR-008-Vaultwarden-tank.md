# ADR-008 — Données de Vaultwarden sur `tank` (volume bloc)

## Statut

Accepté. **Appliqué le 14 oct. 2026**, après une preuve de concept le 6 oct. 2026.

## Contexte

Vaultwarden tournait sur K3s avec un PVC `local-path`, donc sur le disque système de `k3s-01`, dans `rpool`. Perdre `rpool` ou la VM, c'était perdre le coffre.

`tank/vmdata` est déclaré dans Proxmox (`zfspool: tank-vmdata`). Une preuve de concept a validé la chaîne zvol → VM → ext4 → Local PV → PVC → Pod, puis le volume de test a été détruit.

À ce moment-là, les sauvegardes automatiques n'existaient **pas** encore. L'ordre retenu : d'abord mettre les données à l'abri, **puis** automatiser les sauvegardes.

## Décision

Pour les données persistantes critiques de Vaultwarden :

1. un **volume bloc ZFS**, `tank/vmdata/vm-101-vaultwarden-data` (stockage Proxmox `tank-vmdata`, 8 Gio) ;
2. présenté à la VM `k3s-01` en `scsi1`, avec `iothread=1` ;
3. formaté en ext4 et monté par son UUID dans `fstab` ;
4. consommé par Kubernetes via le PV statique `vaultwarden-zfs-pv` (`Retain`) et le PVC `vaultwarden-zfs-pvc`.

Pas de NFS sous SQLite, et pas de pilote CSI ZFS à ce stade.

```
SQLite → PVC vaultwarden-zfs-pvc → Local PV → ext4 → zvol → VM 101 → tank/vmdata
```

Organisation de `tank` :

```
tank
├── vmdata     ← stockage Proxmox « tank-vmdata » : volumes bloc uniquement
│   └── vm-101-vaultwarden-data
├── backups
└── …
```

On ne mélange **pas** de dataset applicatif (du type `tank/vmdata/vaultwarden`) avec les volumes de Proxmox.

## Raisons

- Séparer l'infrastructure (`rpool`) des données (`tank`) : on peut reconstruire Proxmox ou `k3s-01` sans recréer le coffre.
- SQLite reste sur un stockage bloc, local du point de vue de la VM.
- Un Local PV évite d'ajouter un pilote CSI ZFS, alors que le cluster n'a qu'un nœud et que Proxmox gère déjà les zvol.
- Les snapshots ZFS permettent un retour arrière rapide. Ce n'est **pas** une sauvegarde : perdre `tank`, c'est perdre aussi ses snapshots.
- Vaultwarden ne connaît pas ZFS : il voit un PVC, et la chaîne Kubernetes → VM → Proxmox → ZFS fait le reste.
- Le Deployment, le PV et le PVC restent dans Git, appliqués par Argo CD en synchronisation manuelle.

## Alternatives étudiées

| Option | Commentaire |
| --- | --- |
| Rester en `local-path` sur `rpool` | Simple, mais les données disparaissent avec la VM ou le NVMe |
| NFS monté dans le Pod pour SQLite | Éviterait un volume Proxmox, mais SQLite est moins adapté au réseau qu'au bloc. NFS reste envisageable plus tard pour du partage ou comme destination de sauvegarde, pas comme stockage principal de Vaultwarden |
| Dataset de fichiers `tank/vaultwarden` | Possible pour d'autres usages. Ici, les volumes de VM passent uniquement par `tank/vmdata` |
| Pilote CSI ZFS | Une couche de plus. Avec un seul nœud et des volumes déjà gérés par Proxmox, le Local PV suffit. À réévaluer si le cluster passe à plusieurs nœuds, ou si le provisionnement et les snapshots côté Kubernetes deviennent un besoin |

## Validation

- **Preuve de concept du 6 oct. 2026**, volume de test détruit ensuite (voir [stockage-zfs.md](../exploitation/stockage-zfs.md), section 6).
- **Migration du 14 oct. 2026** : sauvegarde à froid, copie aux empreintes SHA-256 identiques, `PRAGMA integrity_check` à `ok` (29 tables), Argo CD `Synced` / `Healthy`, HTTP 200, coffre accessible. L'ancien PVC est conservé (voir [vaultwarden.md](../exploitation/vaultwarden.md), section 9).

## Conséquences

- Le provisionnement des volumes est **manuel** : création dans Proxmox, puis PV statique.
- Le Local PV est lié au nœud `k3s-01`. Pas de haute disponibilité du stockage, ce qui est cohérent avec un cluster à un nœud ([ADR-004](ADR-004-K3s.md)).
- Le volume doit **survivre** à la suppression ou à la recréation de la VM : il faut le rattacher, jamais le détruire par erreur. La procédure est écrite mais n'a jamais été jouée (voir [restauration.md](../exploitation/restauration.md), scénario 3.2).
- L'ancien PVC `vaultwarden-pvc` n'est plus synchronisé depuis la bascule : ce n'est pas un point de retour.
- Le miroir et les snapshots ne remplacent pas une sauvegarde. Depuis, la chaîne de sauvegarde est en place : archive quotidienne depuis le 20 oct., restauration isolée réussie le 21 oct. (connexion, 2FA, coffre). La reprise réelle sur le zvol de production reste à jouer (voir [sauvegardes.md](../exploitation/sauvegardes.md)).
