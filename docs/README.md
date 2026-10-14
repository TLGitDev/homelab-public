# Homelab — documentation

Index des documents. Vue d'ensemble du dépôt : [README.md](../README.md) à la racine.

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
| Accès distant | Tunnel ; Access sur Proxmox et Argo CD ; Vaultwarden sans Access |
| Premier service | LXC `cloudflare` (`<ip-cloudflare>`) |
| Cluster | K3s (`<ip-k3s-01>`), Traefik |
| Application | Vaultwarden (ns `vaultwarden`, Argo CD, `https://vaultwarden.labo.example`) |
| Pool de données | `tank/vmdata` ; Vaultwarden sur zvol `vm-101-vaultwarden-data` ([ADR-008](ADR/ADR-008-Vaultwarden-tank.md)) |
| Sauvegardes | Copies de migration ; routine et copie hors `tank` ⬜ |

---

## Documentation

### Par où commencer

| Fichier | Rôle |
|---------|------|
| [Journal.md](Journal.md) | Chronologie des séances |
| [Architecture.md](Architecture.md) | Principes, schéma actuel, feuille de route |
| [Materiel.md](Materiel.md) | Inventaire physique |
| [Proxmox.md](Proxmox.md) | Nœud : IP, accès, dépôts, systemd |
| [Stockage.md](Stockage.md) | ZFS : `rpool` / `tank`, `tank-vmdata`, volume Vaultwarden |
| [Cloudflare.md](Cloudflare.md) | Tunnel, Access, MFA |
| [Sauvegardes.md](Sauvegardes.md) | RAID ≠ snapshot ≠ backup, RTO/RPO |
| [Kubernetes.md](Kubernetes.md) | Fondamentaux K8s (manifestes, config, conception, Docker → K8s) |
| [ArgoCD.md](ArgoCD.md) | GitOps, App of Apps, UI `argocd.labo.example` |
| [Vaultwarden.md](Vaultwarden.md) | Service : namespace, Traefik, Sealed Secrets |
| [Competences.md](Competences.md) | Niveaux de maîtrise |
| [Glossaire.md](Glossaire.md) | Définitions |

### Décisions (ADR)

| Fichier | Décision |
|---------|----------|
| [ADR-001-Proxmox.md](ADR/ADR-001-Proxmox.md) | Hyperviseur : Proxmox VE |
| [ADR-002-ZFS.md](ADR/ADR-002-ZFS.md) | Stockage : ZFS |
| [ADR-003-Cloudflare-Tunnel.md](ADR/ADR-003-Cloudflare-Tunnel.md) | Accès distant : Cloudflare Tunnel |
| [ADR-004-K3s.md](ADR/ADR-004-K3s.md) | Plateforme : K3s, un nœud |
| [ADR-005-Sealed-Secrets.md](ADR/ADR-005-Sealed-Secrets.md) | Secrets GitOps : Sealed Secrets |
| [ADR-006-Argo-CD.md](ADR/ADR-006-Argo-CD.md) | GitOps : Argo CD |
| [ADR-007-Argo-CD-exposition.md](ADR/ADR-007-Argo-CD-exposition.md) | Exposition Argo CD, config hors `root` |
| [ADR-008-Vaultwarden-tank.md](ADR/ADR-008-Vaultwarden-tank.md) | Vaultwarden : zvol `tank` + Local PV (appliqué) |

---

## Infrastructure cible

Détail et cases à cocher : [Architecture.md](Architecture.md) (feuille de route).
