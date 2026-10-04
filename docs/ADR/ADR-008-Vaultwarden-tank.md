# ADR-008 — Données Vaultwarden sur `tank` (volume bloc)

## Statut

Accepté (cible). **Pas encore appliqué** au service en production.

## Contexte

Vaultwarden tourne sur K3s. Ses données sont aujourd'hui un PVC `local-path` sur le disque de la VM `k3s-01`, donc sur **`rpool`**. Perdre `rpool` ou la VM, c'est perdre le coffre.

`tank` (miroir IronWolf) existe mais n'héberge encore aucun volume applicatif.

Les sauvegardes automatiques ne sont **pas** en place. On fixe d'abord où vivent les données, **puis** on automatisera les backups.

## Décision

Pour les données persistantes critiques de Vaultwarden : un **volume bloc ZFS sur `tank`**, présenté à la VM `k3s-01`, consommé par Kubernetes via un PVC.

Pas de NFS directement sous SQLite.

```
SQLite → filesystem Linux → volume bloc → VM → ZFS tank
```

Organisation :

```
tank
├── vmdata     ← zfspool Proxmox ; volumes bloc uniquement
├── backups    ← rôle éventuel, plus tard
└── …
```

Exemple de volume : `tank/vmdata/vm-101-vaultwarden` (nom exact à confirmer). **Pas** de dataset applicatif du type `tank/vmdata/vaultwarden` mélangé aux volumes Proxmox.

Prochaine étape opérationnelle : **POC** (petit volume de test sur `tank/vmdata`), valider le chemin, **ne pas** migrer Vaultwarden tout de suite.

Détail : [Stockage.md](../Stockage.md). Service : [Vaultwarden.md](../Vaultwarden.md). Backups : [Sauvegardes.md](../Sauvegardes.md).

## Raisons

- Séparer infra (`rpool`) et données (`tank`) : reconstruire Proxmox / k3s-01 sans recréer le coffre.
- SQLite reste sur du bloc « local » du point de vue de la VM.
- Snapshots ZFS possibles (rollback rapide). **Ce n'est pas** une sauvegarde : perte de `tank` = perte des snapshots.
- Vaultwarden ne connaît pas ZFS : PVC → K8s → volume → VM → Proxmox → ZFS.

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| Rester en `local-path` sur `rpool` | Simple. Les données meurent avec la VM / le NVMe. |
| NFS (ou similaire) monté dans le Pod pour SQLite | Évite un volume Proxmox. Moins adapté à SQLite que le bloc. |
| Dataset fichier `tank/vaultwarden` monté autrement | Possible pour d'autres usages. Ici : volumes VM via `tank/vmdata` seulement. |

## Conséquences

- Le volume doit **survivre** à une suppression / recréation de VM : le réattacher, ne pas le détruire par erreur. Procédure de restauration à écrire **après** le POC.
- Miroir + snapshots ≠ backup. Backup indépendant (USB / offsite) **après** cette architecture.
- Première version de backup prévue : arrêt Vaultwarden, copie cohérente (`db.sqlite3`, `rsa_key.pem`, …), vérifs, redémarrage — pas une copie à chaud arbitraire.
