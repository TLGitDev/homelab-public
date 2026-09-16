# Homelab

## Présentation

Ce projet documente la conception, la réalisation et l'exploitation d'un homelab personnel.

L'objectif n'est pas uniquement de disposer d'un serveur fonctionnel, mais de comprendre l'ensemble de l'infrastructure, de documenter chaque décision technique et de développer des compétences transférables dans un contexte professionnel.

---

## Objectifs

- Comprendre chaque technologie utilisée.
- Construire une infrastructure fiable.
- Documenter toutes les décisions.
- Développer des compétences en infrastructure système.
- Produire une documentation maintenable.

---

## Philosophie

Chaque étape suit le cycle suivant :

> Comprendre → Faire → Vérifier → Documenter

Aucune modification importante n'est réalisée sans comprendre le problème qu'elle résout.

---

## État actuel

| Élément | État |
|---------|------|
| Matériel | Validé (Node 804, Ryzen 7 5700G, 32 Go, NVMe 2 To, 2× IronWolf 8 To) |
| Hyperviseur | Proxmox VE sur ZFS (`rpool`), IP `<ip-pve>` |
| Accès distant | Cloudflare Tunnel + Access + MFA |
| Premier service | LXC `cloudflare` (`<ip-cloudflare>`) |
| Pool de données | `tank` créé (miroir 2×8 To), aucun dataset de service |
| Sauvegardes | Stratégie définie, pas encore mise en œuvre |

---

## Documentation

### Par où commencer

| Fichier | Rôle |
|---------|------|
| [Journal.md](Journal.md) | Chronologie des séances |
| [Architecture.md](Architecture.md) | Principes, schéma actuel, feuille de route |
| [Materiel.md](Materiel.md) | Inventaire physique |
| [Proxmox.md](Proxmox.md) | Nœud : IP, accès, dépôts, systemd |
| [Stockage.md](Stockage.md) | ZFS : cours, `rpool`, `tank` |
| [Cloudflare.md](Cloudflare.md) | Tunnel, Access, MFA |
| [Sauvegardes.md](Sauvegardes.md) | RAID ≠ snapshot ≠ backup, RTO/RPO |
| [Kubernetes.md](Kubernetes.md) | Cours Kubernetes (pas encore déployé) |
| [Competences.md](Competences.md) | Niveaux de maîtrise |
| [Glossaire.md](Glossaire.md) | Définitions |

### Décisions (ADR)

| Fichier | Décision |
|---------|----------|
| [ADR-001-Proxmox.md](ADR/ADR-001-Proxmox.md) | Hyperviseur : Proxmox VE |
| [ADR-002-ZFS.md](ADR/ADR-002-ZFS.md) | Stockage : ZFS |
| [ADR-003-Cloudflare-Tunnel.md](ADR/ADR-003-Cloudflare-Tunnel.md) | Accès distant : Cloudflare Tunnel |

---

## Infrastructure cible

Détail et cases à cocher : [Architecture.md](Architecture.md) (feuille de route).
