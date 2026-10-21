# ADR-008 — Données Vaultwarden sur `tank` (volume bloc)

## Statut

Accepté. **Appliqué** le 2026-10-14. POC préalable : 2026-10-06.

## Contexte

Vaultwarden tournait sur K3s avec un PVC `local-path` sur le disque système de `k3s-01` (`rpool`). Perdre `rpool` ou la VM, c'était perdre le coffre.

`tank/vmdata` est exposé à Proxmox (`zfspool: tank-vmdata`). Le chemin zvol → VM → ext4 → Local PV → PVC → Pod a été validé par un POC, puis le volume de test a été détruit.

Les sauvegardes automatiques n'étaient **pas** en place. On a d'abord déplacé les données, **puis** on automatisera les backups.

## Décision

Pour les données persistantes critiques de Vaultwarden :

1. un **volume bloc ZFS** `tank/vmdata/vm-101-vaultwarden-data` (stockage Proxmox `tank-vmdata`, 8 Gio) ;
2. présenté à la VM `k3s-01` (`scsi1`, `iothread=1`) ;
3. filesystem Linux ext4, montage par UUID dans `fstab` ;
4. consommé par Kubernetes via le PV statique `vaultwarden-zfs-pv` (`Retain`) et le PVC `vaultwarden-zfs-pvc`.

Pas de NFS sous SQLite. Pas de CSI ZFS à ce stade.

```
SQLite → PVC vaultwarden-zfs-pvc → Local PV → ext4 → zvol → VM 101 → tank/vmdata
```

Organisation :

```
tank
├── vmdata     ← zfspool Proxmox `tank-vmdata` ; volumes bloc uniquement
│   └── vm-101-vaultwarden-data
├── backups    ← rôle éventuel, plus tard
└── …
```

**Pas** de dataset applicatif du type `tank/vmdata/vaultwarden` mélangé aux volumes Proxmox.

Détail : [Stockage.md](../Stockage.md). Service : [Vaultwarden.md](../Vaultwarden.md). Backups : [Sauvegardes.md](../Sauvegardes.md).

## Raisons

- Séparer infra (`rpool`) et données (`tank`) : reconstruire Proxmox / k3s-01 sans recréer le coffre.
- SQLite reste sur du bloc « local » du point de vue de la VM.
- Un Local PV évite d'introduire un CSI ZFS alors que le cluster n'a qu'un nœud et que Proxmox gère déjà les zvols.
- Snapshots ZFS possibles (rollback rapide). **Ce n'est pas** une sauvegarde : perte de `tank` = perte des snapshots.
- Vaultwarden ne connaît pas ZFS : PVC → K8s → chemin local → VM → Proxmox → ZFS.
- GitOps conserve le Deployment, le PV et le PVC dans Git (sync manuel).

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| Rester en `local-path` sur `rpool` | Simple. Les données meurent avec la VM / le NVMe. |
| NFS (ou similaire) monté dans le Pod pour SQLite | Évite un volume Proxmox. Moins adapté à SQLite que le bloc. NFS reste envisageable plus tard pour du partage ou une destination de backup, pas comme stockage primaire de Vaultwarden. |
| Dataset fichier `tank/vaultwarden` mélangé à `vmdata` | Possible pour d'autres usages. Ici : volumes VM via `tank/vmdata` seulement. |
| CSI ZFS | Couche de plus. Un nœud, volumes déjà gérés par Proxmox, besoin actuel couvert par le Local PV. À réévaluer si le cluster devient multi-nœuds ou si le provisioning / les snapshots Kubernetes deviennent un besoin. |

## Validation

- POC du **2026-10-06** : volume de test détruit ensuite. [Stockage.md](../Stockage.md#poc-6-octobre-2026).
- Migration du **2026-10-14** : sauvegarde arrêtée, copie SHA-256 identique, `PRAGMA integrity_check` ok (29 tables), Argo CD Synced/Healthy, HTTP 200, coffre OK. Ancien PVC conservé. [Vaultwarden.md](../Vaultwarden.md#migration-local-path--tank-2026-10-14).

## Conséquences

- Provisioning des volumes **manuel** (Proxmox + PV statique).
- Le Local PV est lié au nœud `k3s-01`. Pas de HA Kubernetes du stockage — cohérent avec un cluster à un nœud ([ADR-004](ADR-004-K3s.md)).
- Le volume doit **survivre** à une suppression / recréation de VM : le réattacher, ne pas le détruire par erreur. Procédure de restauration à **tester**.
- L'ancien PVC `vaultwarden-pvc` est un rollback **figé** : plus synchronisé depuis la bascule.
- Miroir + snapshots ≠ backup. Chaîne quotidienne : [Vaultwarden.md](../Vaultwarden.md#sauvegarde). Tars auto 20–21 oct. ; restore isolée OK (login 21 oct.) ; reprise sur le zvol de prod : encore ouverte.
