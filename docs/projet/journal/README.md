# Journal de bord

Le journal raconte le projet séance par séance, depuis l'assemblage du serveur le 27 août 2026. Il garde la trace de ce qui a été tenté, réussi ou raté, et de ce qui a été appris. L'état actuel, lui, est décrit dans [architecture.md](../../vue-ensemble/architecture.md) ; la cible, dans la [feuille de route](../../FeuilleDeRoute.md).

## Comment il est organisé

- **Un fichier par mois.** Chaque fichier contient les séances du mois (les *sprints*), puis les évolutions jour par jour.
- **Un sprint** a son propre chapitre : objectif, réalisé, vérifications, difficultés, compétences acquises, décisions et prochaine étape. Il correspond à une séance d'infrastructure, d'étude ou à une preuve de concept.
- **Les évolutions jour par jour** recensent tout ce qui a bougé, y compris les jours où seule la documentation a changé (extraction d'un document, nouvel ADR, précisions). Ces lignes n'ont pas forcément de numéro de sprint. Exemple : l'ADR-008 date du 4 oct. (évolution seule), la preuve de concept `tank/vmdata` du 6 oct. (sprint 19).
- À partir du 22 oct. 2026, le travail est suivi par **phases** (voir la feuille de route) et noté dans les évolutions jour par jour, sans nouveau chapitre de sprint.

## Origine des dates

Les sprints 1 à 3 ont été rédigés le jour même. Les sprints 4 à 8 ont été reconstitués le 2 sept. 2026 à partir de l'historique local de Cursor (sauvegardes datées des fichiers Markdown) : ce sont donc les dates auxquelles le travail a été **documenté**. Sans Git à l'époque, l'heure exacte des commandes sur le serveur n'est pas connue. Les 30 août et 1er sept. 2026 n'ont laissé aucune trace de documentation.

## Index des séances

| Date | Sprint | Séance | Fichier |
| --- | --- | --- | --- |
| 27 août 2026 | 1 | Validation matérielle | [août](2026-08.md) |
| 27 août 2026 | 2 | Installation de Proxmox VE | [août](2026-08.md) |
| 28 août 2026 | 3 | Mise en service de Proxmox | [août](2026-08.md) |
| 29 août 2026 | 4 | Étude de ZFS | [août](2026-08.md) |
| 31 août 2026 | 5 | LXC et conventions | [août](2026-08.md) |
| 31 août 2026 | 6 | Cloudflare Tunnel et Access | [août](2026-08.md) |
| 2 sept. 2026 | 7 | Sauvegardes et incident IP | [septembre](2026-09.md) |
| 2 sept. 2026 | 8 | Réinstallation de Proxmox sur ZFS | [septembre](2026-09.md) |
| 7 sept. 2026 | 9 | Pool `tank` | [septembre](2026-09.md) |
| 16 sept. 2026 | 10 | Étude de Kubernetes | [septembre](2026-09.md) |
| 19 sept. 2026 | 11 | Ressources Kubernetes (Pod, ReplicaSet, Deployment) | [septembre](2026-09.md) |
| 20 sept. 2026 | 12 | Stockage Kubernetes (PVC, PV, StorageClass) | [septembre](2026-09.md) |
| 21 sept. 2026 | 13 | Anatomie des manifestes | [septembre](2026-09.md) |
| 21 sept. 2026 | 14 | ConfigMap, Secret et composition d'une application | [septembre](2026-09.md) |
| 25 sept. 2026 | 15 | Conception d'une application Kubernetes | [septembre](2026-09.md) |
| 27 sept. 2026 | 16 | Vaultwarden sur K3s | [septembre](2026-09.md) |
| 27 sept. 2026 | 17 | SOPS + age pour ADMIN_TOKEN | [septembre](2026-09.md) |
| 29 sept. 2026 | 18 | Namespace vaultwarden, Sealed Secrets, Argo CD | [septembre](2026-09.md) |
| 6 oct. 2026 | 19 | POC `tank/vmdata` et Local PV | [octobre](2026-10.md) |
| 14 oct. 2026 | 20 | Migration Vaultwarden vers `tank` | [octobre](2026-10.md) |
| 17 oct. 2026 | 21 | `ADMIN_TOKEN` en Argon2id | [octobre](2026-10.md) |
| 19 oct. 2026 | 22 | Sauvegardes Vaultwarden automatisées | [octobre](2026-10.md) |
| 20 oct. 2026 | 23 | Restore technique Vaultwarden | [octobre](2026-10.md) |
| 21 oct. 2026 | 24 | Restore fonctionnel Vaultwarden | [octobre](2026-10.md) |

## Évolutions par mois

| Mois | Séances | Lignes d'évolution |
| --- | --- | --- |
| [Août 2026](2026-08.md) | 6 | 4 |
| [Septembre 2026](2026-09.md) | 12 | 16 |
| [Octobre 2026](2026-10.md) | 6 | 99 |
| [Novembre 2026](2026-11.md) | 0 | 82 |
