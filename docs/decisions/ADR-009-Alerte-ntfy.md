# ADR-009 — Alerte : ntfy

## Statut

Accepté le 5 nov. 2026, et appliqué le même jour. **Validé en conditions réelles** : une vraie sauvegarde en échec a bien déclenché une alerte sur le téléphone.

Mise en place du 5 nov. :
- sujet créé, et `notify-ntfy` installé sur `pve` et `k3s-01` ;
- essai d'échec reçu, puis unit d'essai retirée ;
- contrôle de 08:15 activé ;
- scrub planifié le premier dimanche du mois, et non lancé ce jour-là ;
- rétention Restic appliquée sur le run `<snapshot>` : 6 snapshots gardés, 7 retirés, `prune` de 3,999 Kio.

## Contexte

Les sauvegardes tournaient déjà (phase 0), mais leurs pannes restaient invisibles tant qu'on n'ouvrait pas une session :

- un timer peut échouer ;
- le disque USB peut rester débranché ;
- `tank` peut quitter l'état `ONLINE` ;
- un scrub peut finir en erreur ;
- un pool peut se remplir.

La phase 5 demande **un seul canal**, et un message qui arrive sans SSH. Trois pistes étaient ouvertes : ntfy, le courriel et Healthchecks.

## Décision

**ntfy**, avec l'application sur le téléphone et l'instance publique `ntfy.sh`.

- **Le sujet est le secret.** Il est long et aléatoire, stocké dans `/etc/homelab/ntfy-topic` (mode `600`, root). Il n'apparaît ni dans Git, ni dans le journal, ni dans le texte des messages.
- `pve` et `k3s-01` publient en HTTPS sortant : rien n'écoute en entrée.
- Pas d'instance ntfy hébergée ici.

Seuils fixés en même temps :

| Seuil | Valeur |
| --- | --- |
| Rétention Restic | 14 jours (`forget --keep-within 14d --group-by host`) |
| Âge maximal de la dernière copie USB | 14 jours, le même nombre |
| Espace libre minimal | 10 %, sur `tank` et sur `rpool` |
| Scrub de `tank` | Le premier dimanche du mois, à 05:00 |

La date de la dernière copie USB est un fichier sur `pve`, écrit seulement après un `backup-usb` réussi. Le disque étant démonté le reste du temps, le contrôle ne peut pas interroger Restic directement.

## Raisons

- Le téléphone reçoit le texte de la panne, même hors du LAN, sans tableau de bord à ouvrir.
- Aucun service de plus à sauvegarder. Une instance locale mourrait avec la machine qu'elle doit surveiller, ou il faudrait l'exposer sur Internet.
- **Pourquoi 14 jours ?** La copie USB est manuelle. Avec 7 jours, on ne garderait qu'une génération si le disque n'est branché qu'une fois par semaine, et l'alerte partirait le jour même où la copie est due. Avec 30 jours, on pourrait rester un mois sans copie. 14 jours laissent environ deux copies hebdomadaires, et préviennent si deux semaines passent sans copie.

## Alternatives étudiées

| Option | Pourquoi elle n'est pas retenue |
| --- | --- |
| Courriel | Un secret SMTP en plus sur l'hôte des sauvegardes. Des délais, et un risque de dossier spam |
| Healthchecks.io | Détecte un ping qui ne vient pas, mais a besoin d'un autre canal pour prévenir : deux systèmes au lieu d'un. Le contrôle quotidien couvre déjà l'oubli du disque USB, tant que `pve` tourne |
| ntfy hébergé sur `pve` ou `k3s-01` | Le canal tomberait avec l'hôte, ou il faudrait une entrée publique |

## Limites

- **Si `pve` est arrêté, le contrôle quotidien ne part pas**, et ntfy ne devine pas un silence. C'est le trou que Healthchecks aurait couvert.
- Un snapshot du zvol qui échoue chaque heure envoie un message chaque heure.
- Au premier run après une alerte d'âge, `forget` retire ce qui a plus de 14 jours, avant de créer le nouveau snapshot. La génération précédente peut donc disparaître à ce moment-là. Elle ne disparaît pas pendant l'oubli lui-même, car `forget` ne tourne que dans `backup-usb`.
- `ntfy.sh` voit le texte des messages. Ce texte ne contient que la nature de la panne (`tank`, `copie USB`, un nom d'unit), jamais un mot de passe, une empreinte ou le sujet.
- Qui connaît le sujet peut lire et publier : le fichier reste en `600`.

## Révisions

- **6 nov. 2026** : premier incident réel. À 04:00, le snapshot horaire et le quotidien sont partis en même temps. L'horaire a échoué (`Un snapshot est déjà en cours.`), ce qui a déclenché `OnFailure` et un message ntfy. Le script attend désormais son tour sur le verrou (voir [sauvegardes.md](../exploitation/sauvegardes.md), section 10).
- **11 nov. 2026** : l'alerte est confirmée comme reçue lors d'une vraie sauvegarde en échec.

Exploitation : [sauvegardes.md](../exploitation/sauvegardes.md), section 7.
