# Matériel

Ce document recense les composants physiques du serveur `pve` et leur emplacement. Les choix d'architecture sont justifiés dans les [ADR](../decisions/), et l'histoire du montage est dans le [journal](../projet/journal/).

## 1. Configuration

Tous les composants sont installés et validés.

| Composant | Modèle | Rôle |
| --- | --- | --- |
| Boîtier | Fractal Design Node 804 | Châssis |
| Carte mère | MSI B550M PRO-VDH WIFI | Plateforme AM4 |
| Processeur | AMD Ryzen 7 5700G | Calcul de l'hyperviseur |
| Refroidissement CPU | AMD Wraith Stealth | Ventirad d'origine |
| Mémoire | 32 Go DDR4 (2 × 16 Go) | Mémoire système |
| SSD système | WD Black SN7100 2 To (NVMe) | Proxmox, VM et conteneurs |
| Disque de données 1 | Seagate IronWolf Pro 8 To | Miroir ZFS `tank` |
| Disque de données 2 | Seagate IronWolf Pro 8 To | Miroir ZFS `tank` |
| Alimentation | MSI MAG A650BN 650 W | Alimentation |
| Onduleur | Eaton Ellipse 700 VA | Protège le serveur contre les coupures |

## 2. Répartition du stockage

| Support | Pool ZFS | Contenu |
| --- | --- | --- |
| SSD NVMe 2 To | `rpool` | Proxmox, disques des VM et des conteneurs, ISO |
| IronWolf 1 + IronWolf 2 | `tank` (miroir) | Données |

Le système repose sur un seul NVMe : il n'a pas de redondance. Les données, elles, sont en miroir sur deux disques. Le détail est dans [stockage-zfs.md](../exploitation/stockage-zfs.md).

## 3. Identification des disques

Les noms Linux (`/dev/sda`, `/dev/sdb`) peuvent changer d'un démarrage à l'autre. Le **numéro de série** est l'identifiant permanent d'un disque : c'est lui qu'il faut utiliser pour savoir lequel remplacer.

| Position | Port SATA | Nom Linux à l'installation | Numéro de série | Modèle |
| --- | --- | --- | --- | --- |
| HDD1 | SATA1 | `/dev/sda` | `<numéro-de-série-hdd1>` | ST8000NT001-3LZ101 |
| HDD2 | SATA2 | `/dev/sdb` | `<numéro-de-série-hdd2>` | ST8000NT001-3LZ101 |

## 4. Emplacements sur la carte mère

| Élément | Emplacement |
| --- | --- |
| SSD NVMe | M2_1 (sous son dissipateur) |
| IronWolf 1 | SATA1 |
| IronWolf 2 | SATA2 |
| Barrettes de RAM | A2 + B2 (double canal) |
| Ventilateur CPU | CPU_FAN1 |

Les ventilateurs du boîtier sont branchés sur le hub Fractal. Ce hub a besoin de sa propre alimentation SATA. Son sélecteur de vitesse (H / M / L) est réglé sur **M**.

## 5. BIOS

| Paramètre | Valeur |
| --- | --- |
| Mode de démarrage | UEFI |
| Mémoire détectée | 32 Go |
| SSD détecté | Oui |
| Disques durs détectés | Oui |

## 6. Procédures

### 6.1 Identifier physiquement un disque de `tank`

À utiliser avant tout remplacement, pour ne pas débrancher le mauvais disque.

**Prérequis**

- Un shell `root` sur `pve`.
- Le tableau de la section 3 sous les yeux.

**Action**

1. Repérer le disque en défaut dans le pool : `zpool status tank` (standard).
2. Lire son numéro de série : `ls -l /dev/disk/by-id/ | grep ata-` (standard), ou `smartctl -i /dev/<disque>`.
3. Retrouver ce numéro dans le tableau de la section 3 pour obtenir sa position (HDD1 ou HDD2) et son port SATA.

**Vérification**

- Le numéro de série lu sur l'étiquette du disque, dans le boîtier, est identique à celui affiché par Linux.

### 6.2 Nettoyer le serveur

**Prérequis**

- Le serveur est arrêté proprement depuis Proxmox, puis débranché.

**Action**

| Élément | Fréquence |
| --- | --- |
| Filtres à poussière du Node 804 | Tous les 3 mois |
| Ventilateurs | Tous les 6 mois |
| Intérieur du boîtier | Tous les 6 mois |

**Vérification**

- Au redémarrage, tous les ventilateurs tournent.
- `zpool status` montre les deux pools `ONLINE` (standard).

## 7. Validation initiale

Le matériel a été validé en deux temps, le 27 août 2026 (voir le [journal](../projet/journal/)).

| Étape | Contrôles réussis |
| --- | --- |
| Test hors boîtier (bench test) | Premier POST, CPU, RAM, SSD, BIOS |
| Montage définitif | Carte mère, alimentation, SSD, deux disques durs, ventilateurs, ports USB en façade, démarrage dans le boîtier |

## 8. Évolutions envisagées

- Ajouter de la mémoire.
- Ajouter un second SSD NVMe, ce qui supprimerait le point unique de défaillance de `rpool`.
- Ajouter une carte réseau 10 GbE.
