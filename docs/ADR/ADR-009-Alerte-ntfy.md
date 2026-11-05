# ADR-009 — Une alerte, par ntfy

## Statut

Accepté le 2026-11-05. **Pas appliqué** : les units ne sont pas encore sur `pve` ni sur `k3s-01`.

## Contexte

Les sauvegardes tournent déjà (phase 0). Un timer peut échouer, la clé USB peut rester débranchée, `tank` peut quitter `ONLINE`, un scrub peut finir avec des erreurs, un pool peut se remplir. Aujourd'hui ça se voit en ouvrant une session.

La phase 5 demande un seul canal. Le message doit arriver sans SSH. Trois pistes étaient ouvertes : ntfy, courriel, healthchecks.

## Décision

**ntfy**, appli sur le téléphone, instance publique `ntfy.sh`.

- Le sujet est long et aléatoire. Il est le secret. Fichier `/etc/homelab/ntfy-topic`, mode `600`, root. Pas dans Git, pas dans le journal, pas dans le corps du message.
- `pve` et `k3s-01` publient en HTTPS sortant. Rien n'écoute en entrée.
- Pas d'instance hébergée ici.

Nombres écrits en même temps :

| Seuil | Valeur |
|-------|--------|
| Rétention Restic | 14 jours (`forget --keep-within 14d --group-by host`) |
| Âge de la dernière copie USB | 14 jours, le même nombre |
| Espace libre | sous 10 % sur `tank` et sur `rpool` |
| Scrub de `tank` | le premier dimanche du mois, 05:00 |

La date USB est un fichier sur `pve`, écrit seulement après un `backup-usb` réussi. La clé est démontée le reste du temps : le contrôle ne peut pas interroger Restic.

## Raisons

- Le téléphone reçoit le texte de la panne, y compris hors du LAN. Pas de tableau à ouvrir.
- Aucun service de plus à sauvegarder. Une instance locale mourrait avec la machine qu'elle devrait surveiller, ou il faudrait l'exposer.
- Le courriel ajoute un secret SMTP sur l'hôte des sauvegardes, et la boîte peut retenir le message.
- Healthchecks voit un ping qui ne vient pas, puis il faut encore un canal pour le dire. Ça fait deux systèmes. Le contrôle quotidien couvre déjà l'oubli de la clé USB, tant que `pve` tourne.

14 jours : la copie USB est manuelle. Sept jours ne garderait qu'une génération si la clé n'est branchée qu'une fois par semaine, et l'alerte partirait le jour où le run est dû. Trente jours laisserait un mois sans copie. Quatorze jours laisse environ deux copies hebdomadaires, et prévient si deux semaines passent.

## Limites

- Si `pve` ne tourne pas, le contrôle quotidien ne part pas. ntfy ne devine pas le silence. C'est le trou que healthchecks aurait couvert.
- Un snapshot zvol qui échoue chaque heure envoie un message chaque heure.
- Au run qui suit une alerte d'âge, `forget` retire ce qui a plus de 14 jours avant le nouveau snapshot. La génération d'avant peut disparaître à ce moment-là. Elle ne disparaît pas toute seule pendant l'oubli : `forget` ne tourne que dans `backup-usb`.
- `ntfy.sh` voit le texte. Le texte dit la panne (`tank`, `copie USB`, un nom d'unit). Pas un mot de passe, pas une empreinte, pas le sujet.
- Qui connaît le sujet peut lire et publier. Le fichier reste en `600`.

## Alternatives étudiées

| Option | Pourquoi écartée |
|--------|------------------|
| Courriel | Secret SMTP en plus. Délai et dossier de spam. |
| healthchecks.io | Détecte un ping manquant, mais le message passe ensuite par un autre canal. |
| ntfy hébergé sur `pve` ou `k3s-01` | Le canal tombe avec l'hôte, ou il faut une entrée publique. |
