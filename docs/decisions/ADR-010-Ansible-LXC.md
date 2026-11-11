# ADR-010 — LXC d'infrastructure : Ansible

## Statut

Accepté le 7 nov. 2026, et joué le même jour sur le conteneur d'essai CT 108 : conteneur créé par le playbook, runner enregistré, « Essai n° 3 » vert en 2 s (commit `4ce9657`), deuxième passe sans changement. Le CT 108 a ensuite été retiré. Le conteneur en service reste le CT 107.

La phase 8 a ensuite appliqué le même modèle aux autres conteneurs, les 8 et 9 nov. 2026.

## Contexte

Les LXC en service ont été créés à la main. La phase 7 demande qu'**une commande** recrée le runner, et qu'**une deuxième passe ne change rien**.

Les applications du cluster sont déjà des manifestes, lus par Argo CD. Proxmox, l'hyperviseur, est en place : son installation reste un mode opératoire manuel ([ADR-001](ADR-001-Proxmox.md)).

## Décision

Trois périmètres :

| Ce qui est décrit… | …par |
| --- | --- |
| Les LXC d'infrastructure | **Ansible**, lancé depuis le PC |
| Les applications déjà en manifestes | Argo CD, comme avant |
| Proxmox lui-même | Un mode opératoire écrit. Le playbook ne le réinstalle pas |

Le premier playbook vise un **runner d'essai**, et non le runner en service : CT 108, nom `runner-essai`, adresse `<ip-runner-ct108>/24`. Une tâche fait échouer le playbook si l'ID visé est 107. Les fichiers sont dans `infrastructure/ansible/`. `secrets.yml` est ignoré par Git, et le fichier `.runner` n'entre pas dans le dépôt. L'enregistrement auprès de Gitea est une étape séparée.

Le playbook parle à l'API de `pve`, puis entre dans le conteneur par `pct`. Il ne tourne **pas** sur le runner.

## Raisons

- Un seul outil pour décrire les conteneurs. Le choix du 4 nov. avait déjà écarté un second outil pour un seul conteneur.
- Le runner exécute le code que le dépôt vient de recevoir. Lancer le playbook depuis le PC évite de lui donner de quoi recréer l'hyperviseur.
- Argo CD est déjà la source des applications du cluster. Les redécrire en Ansible créerait deux sources pour le même objet.
- Recréer Proxmox suppose une machine déjà en place pour lancer la commande : son installation reste donc un mode opératoire.

## Alternatives étudiées

| Option | Commentaire |
| --- | --- |
| Terraform ou OpenTofu | Décrit aussi un conteneur, mais c'est un second outil, écarté le 4 nov. |
| Continuer les `pct create` à la main | Chaque conteneur reste un récit, et on ne peut pas constater qu'une deuxième passe ne change rien |
| Lancer le playbook sur le runner | Un job de CI aurait alors un chemin vers l'hyperviseur |

## Conséquences

- La preuve a été faite sur le CT 108 (Essai n° 3, commit `4ce9657`, vert en 2 s), sans toucher au CT 107.
- **Choix du 7 nov.** : retirer le 108 (`pct destroy 108 --purge`) et garder le récit sur le 107. Relancer le playbook recréerait le 108.
- **La phase 8 reprend ce modèle**, un conteneur à la fois, toujours en commençant par un essai. Chaque conteneur d'essai a ensuite été retiré (`pct stop`, puis `pct destroy --purge`), et relancer son playbook le recréerait :

| Conteneur d'essai | Copie de | Date | Résultat |
| --- | --- | --- | --- |
| CT 109 `navidrome-essai`, `<ip-navidrome-ct109>/24` | CT 106 | 8 nov. | Réponse locale HTTP 200 ou 302, deuxième passe sans changement |
| CT 110 `jellyfin-essai`, `<ip-jellyfin-ct110>/24` | CT 103 | 8 nov. | `/health` à `Healthy`, deuxième passe sans changement. Le paquet 12.4 dépend de `jellyfin-ffmpeg8` 8.1.3-2-trixie ; le 103 a encore `jellyfin-ffmpeg7` |
| CT 111 `samba-essai`, `<ip-samba-ct111>/24` | CT 102 | 8 nov. | `smbd` actif, `nmbd` arrêté, écriture refusée, deuxième passe sans changement. Cinq dossiers en lecture seule, aucun mot de passe Samba |
| CT 112 `servarr-essai`, `<ip-servarr-ct112>/24` | CT 105 | 8 nov. | Pages locales HTTP 200 ou 302, écriture refusée, deuxième passe sans changement. `/tank/mediatheques` en lecture seule, aucune clé d'API, pas de `recyclarr sync` |
| CT 113 `qbittorrent-essai`, `<ip-qbittorrent-ct113>/24` | CT 104 | 8 nov. | Page locale, écriture refusée, sortie du compte coupée (`000`), root sort encore (`301`), deuxième passe sans changement. Clé WireGuard propre vers `192.0.2.1`, `proton-port` arrêté |
| CT 114 `cloudflare-essai`, `<ip-cloudflare-ct114>/24` | CT 100 | 8 nov. | `cloudflared` 2026.10.7 arrêté et désactivé, deuxième passe sans changement. Pas le jeton du tunnel. Le 100 reste en 2026.10.4 |

- **Le CT 115 `wireguard`** a été créé directement par son playbook, le 9 nov., et il est resté en service.
- Les montages de `tank` en lecture seule sont posés par `pct` sur `pve`, car l'API refuse un *bind mount* demandé avec un jeton.
- Le jeton d'API Proxmox et le jeton d'enregistrement Gitea sont dans `infrastructure/ansible/secrets.yml`, hors du dépôt.

Exploitation : [ansible.md](../exploitation/ansible.md).
