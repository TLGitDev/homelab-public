# ADR-008 — Données Vaultwarden sur `tank` (volume bloc)

## Statut

Accepté. Chemin de stockage **validé** par un POC (2026-10-06). **Pas encore appliqué** au Vaultwarden de production.

## Contexte

Vaultwarden tourne sur K3s. Ses données sont aujourd'hui un PVC `local-path` sur le disque système de la VM `k3s-01` (`rpool/data/vm-101-disk-1`). Perdre `rpool` ou la VM, c'est perdre le coffre.

`tank/vmdata` existe et est exposé à Proxmox (`zfspool: tank-vmdata`). Aucun volume applicatif n'y reste après le POC.

Les sauvegardes automatiques ne sont **pas** en place. On fixe d'abord où vivent les données, **puis** on automatisera les backups.

## Décision

Pour les données persistantes critiques de Vaultwarden :

1. un **volume bloc ZFS** sous `tank/vmdata` (stockage Proxmox `tank-vmdata`) ;
2. présenté à la VM `k3s-01` ;
3. filesystem Linux (ext4 au POC) ;
4. consommé par Kubernetes via un **PersistentVolume local statique** et un PVC.

Pas de NFS sous SQLite. Pas de CSI ZFS à ce stade.

```
SQLite → PVC → Local PV → filesystem Linux → zvol → VM → tank/vmdata
```

Organisation :

```
tank
├── vmdata     ← zfspool Proxmox `tank-vmdata` ; volumes bloc uniquement
├── backups    ← rôle éventuel, plus tard
└── …
```

Nom du volume Vaultwarden : à fixer à la migration. **Pas** de dataset applicatif du type `tank/vmdata/vaultwarden` mélangé aux volumes Proxmox.

Prochaine étape : **conception détaillée de la migration** (sauvegarde préalable, rollback, conservation de l'ancien PVC). Ne pas migrer tant que cette procédure n'est pas écrite.

Détail : [Stockage.md](../Stockage.md). Service : [Vaultwarden.md](../Vaultwarden.md). Backups : [Sauvegardes.md](../Sauvegardes.md).

## Raisons

- Séparer infra (`rpool`) et données (`tank`) : reconstruire Proxmox / k3s-01 sans recréer le coffre.
- SQLite reste sur du bloc « local » du point de vue de la VM.
- Un Local PV évite d'introduire un CSI ZFS alors que le cluster n'a qu'un nœud et que Proxmox gère déjà les zvols.
- Snapshots ZFS possibles (rollback rapide). **Ce n'est pas** une sauvegarde : perte de `tank` = perte des snapshots.
- Vaultwarden ne connaît pas ZFS : PVC → K8s → chemin local → VM → Proxmox → ZFS.

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| Rester en `local-path` sur `rpool` | Simple. Les données meurent avec la VM / le NVMe. |
| NFS (ou similaire) monté dans le Pod pour SQLite | Évite un volume Proxmox. Moins adapté à SQLite que le bloc. NFS reste envisageable plus tard pour du partage ou une destination de backup, pas comme stockage primaire de Vaultwarden. |
| Dataset fichier `tank/vaultwarden` mélangé à `vmdata` | Possible pour d'autres usages. Ici : volumes VM via `tank/vmdata` seulement. |
| CSI ZFS | Couche de plus. Un nœud, volumes déjà gérés par Proxmox, besoin actuel couvert par le Local PV. À réévaluer si le cluster devient multi-nœuds ou si le provisioning / les snapshots Kubernetes deviennent un besoin. |

## Validation

POC du **2026-10-06** : volume de test `tank/vmdata/vm-9999-k8s-test` (1 GiB), attaché à `k3s-01`, ext4, Local PV + PVC, écriture depuis un Pod, lecture identique dans la VM.

Le POC a ensuite été **entièrement supprimé** (Pod, PVC, PV, montage, disque, zvol). Aucune donnée Vaultwarden n'a été modifiée. Détail : [Stockage.md](../Stockage.md#poc-6-octobre-2026).

## Conséquences

- Provisioning des volumes **manuel** (Proxmox + PV statique).
- Le Local PV est lié au nœud `k3s-01`. Pas de HA Kubernetes du stockage — cohérent avec un cluster à un nœud ([ADR-004](ADR-004-K3s.md)).
- Le volume doit **survivre** à une suppression / recréation de VM : le réattacher, ne pas le détruire par erreur. Procédure de restauration à écrire **avant** la migration, et à tester.
- Pendant la migration : conserver l'ancien PVC `local-path` comme rollback jusqu'à validation.
- Miroir + snapshots ≠ backup. Backup indépendant (USB / offsite) **après** cette architecture.
- Première version de backup prévue : arrêt Vaultwarden, copie cohérente (`db.sqlite3`, `rsa_key.pem`, …), vérifs, redémarrage — pas une copie à chaud arbitraire.
