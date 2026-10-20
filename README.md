# Homelab

Conception, réalisation et exploitation d'un homelab personnel.

L'objectif n'est pas seulement un serveur qui marche : comprendre chaque couche, justifier les choix, et produire une documentation réutilisable dans un contexte professionnel.

> Comprendre → Faire → Vérifier → Documenter

---

## Organisation

| Chemin | Rôle |
|--------|------|
| [docs/](docs/) | Journal, architecture, ADR, matériel, compétences |
| [kubernetes/](kubernetes/) | Manifestes GitOps (Vaultwarden, Argo CD) |
| [infrastructure/](infrastructure/) | Scripts et systemd (`k3s-01`, `pve`). Git ≠ fichiers installés. |

Les sources dans `infrastructure/` ne se déploient pas toutes seules. Chaîne de sauvegarde : [docs/Sauvegardes.md](docs/Sauvegardes.md).

La racine du dépôt est le projet. `docs/` n'est que la partie écrite.

---

## Par où commencer

1. [docs/README.md](docs/README.md) — index de la doc
2. [docs/Architecture.md](docs/Architecture.md) — état de conception
3. [docs/Journal.md](docs/Journal.md) — historique des séances

---

## Dépôt

Branche : `master`.
