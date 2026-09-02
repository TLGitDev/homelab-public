# Matériel

> Inventaire matériel du serveur.
>
> Ce document décrit uniquement les composants physiques de l'infrastructure.
> Les choix d'architecture sont documentés dans les ADR et le journal de bord.

---

# Configuration actuelle

| Composant | Modèle | Rôle | État |
|-----------|--------|------|------|
| Boîtier | Fractal Design Node 804 | Châssis | ✅ Installé |
| Carte mère | MSI B550M PRO-VDH WIFI | Plateforme AM4 | ✅ Installée |
| Processeur | AMD Ryzen 7 5700G | Hyperviseur | ✅ Installé |
| Refroidissement CPU | AMD Wraith Stealth | Refroidissement | ✅ Installé |
| Mémoire | 32 Go DDR4 (2×16 Go) | Mémoire système | ✅ Installée |
| SSD système | WD Black SN7100 2 To | Proxmox + VM | ✅ Installé |
| HDD 1 | Seagate IronWolf Pro 8 To | ZFS Mirror | ✅ Installé |
| HDD 2 | Seagate IronWolf Pro 8 To | ZFS Mirror | ✅ Installé |
| Alimentation | MSI MAG A650BN 650 W | Alimentation | ✅ Installée |
| Onduleur | Eaton Ellipse 700 VA | Protection électrique | ⏳ À installer |

---

# Répartition du stockage

| Support | Utilisation prévue |
|---------|--------------------|
| SSD NVMe 2 To | Proxmox, VM, conteneurs, ISO, snapshots |
| HDD 1 | ZFS Mirror |
| HDD 2 | ZFS Mirror |

---

# Emplacements

## Carte mère

| Élément | Position |
|---------|----------|
| SSD NVMe | M2_1 |
| IronWolf 1 | SATA1 |
| IronWolf 2 | SATA2 |
| RAM | A2 + B2 |

---

# Ventilation

| Élément | Configuration |
|---------|---------------|
| Ventilateur CPU | CPU_FAN1 |
| Ventilateurs boîtier | Hub Fractal alimenté en SATA |
| Contrôleur | H / M / L |
| Réglage actuel | M |

---

# BIOS

| Paramètre | Valeur |
|-----------|---------|
| Mode | UEFI |
| Mémoire détectée | 32 Go |
| SSD détecté | Oui |
| HDD détectés | Oui |

---

# Validation matérielle

## Bench Test

- ✅ Premier POST hors boîtier
- ✅ Validation CPU
- ✅ Validation RAM
- ✅ Validation SSD
- ✅ Validation BIOS

## Montage définitif

- ✅ Carte mère installée
- ✅ Alimentation installée
- ✅ SSD installé
- ✅ Deux HDD installés
- ✅ Ventilateurs fonctionnels
- ✅ USB façade fonctionnels
- ✅ Démarrage dans le boîtier validé

---

# Maintenance

À compléter au fil du projet.

## Nettoyage

| Élément | Fréquence |
|---------|-----------|
| Filtres du Node 804 | Tous les 3 mois |
| Ventilateurs | Tous les 6 mois |
| Intérieur du boîtier | Tous les 6 mois |

---

# Évolutions possibles

- [ ] Ajouter de la mémoire.
- [ ] Ajouter un second SSD NVMe.
- [ ] Ajouter une carte réseau 10 GbE.
- [ ] Installer l'onduleur.

## Cartographie du stockage

### SSD système

- WD_BLACK SN7100 2 To
- Usage :
  - Proxmox
  - VM
  - Conteneurs
  - ISO

### Disques de données

| Position | Port SATA | Linux (installation) | Numéro de série | Modèle | Usage |
|----------|-----------|----------------------|-----------------|---------|-------|
| HDD1 | SATA1 | /dev/sda | <numéro-de-série-hdd1> | ST8000NT001-3LZ101 | Futur miroir ZFS |
| HDD2 | SATA2 | /dev/sdb | <numéro-de-série-hdd2> | ST8000NT001-3LZ101 | Futur miroir ZFS |

> Les identifiants Linux (`/dev/sda`, `/dev/sdb`) peuvent changer.
> Les numéros de série sont les identifiants permanents des disques.