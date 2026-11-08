# ADR-010 — Les LXC d'infra en Ansible

## Statut

Accepté le 2026-11-07. Jouée le même jour sur le CT 108 : créé par le playbook, runner enregistré, Essai n° 3 verte en 2 s (`4ce9657`). Deuxième passe sans changement. Le 108 a ensuite été retiré. Le récit reste sur le 107, en service.

## Contexte

Les LXC en service ont été créés à la main. La phase 7 demande qu'une commande refasse le runner, et qu'une deuxième passe ne change rien.

Les applications du cluster sont déjà des manifestes. Argo CD les lit. Proxmox, l'hyperviseur, est en place : son installation reste un mode opératoire ([ADR-001](ADR-001-Proxmox.md)).

## Décision

Trois périmètres.

- Les LXC d'infra se décrivent en Ansible, lancé depuis le PC.
- Les applications déjà en manifestes restent dans Argo CD.
- Proxmox lui-même reste un mode opératoire. Le playbook ne le réinstalle pas.

Le premier playbook vise le runner d'essai, pas le runner en service. CT 108, nom `runner-essai`, adresse `<ip-runner-ct108>/24`. Une tâche s'arrête si le numéro visé est 107. Fichiers : `infrastructure/ansible/`. `secrets.yml` est ignoré par Git. Le fichier `.runner` n'entre pas dans le dépôt. L'enregistrement auprès de Gitea est une tâche à part.

Le playbook parle à l'API de `pve`, puis entre dans le CT par `pct`. Il ne tourne pas sur le runner.

## Raisons

- Un seul outil pour décrire les conteneurs. Le choix du 4 nov. écarte un second outil pour un seul CT.
- Le runner exécute le script que le dépôt vient de pousser. Le playbook lancé depuis le PC ne lui donne pas de quoi recréer l'hyperviseur.
- Argo CD est déjà la source des applications du cluster. Les redécrire en Ansible ferait deux sources pour le même objet.
- Recréer Proxmox suppose une machine déjà là pour lancer la commande. L'installation de `pve` reste le mode opératoire.

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| Terraform ou OpenTofu | Décrit aussi un CT. C'est un second outil, écarté le 4 nov. |
| Continuer les `pct create` à la main | Chaque CT reste un récit. Une deuxième passe ne se constate pas. |
| Lancer le playbook sur le runner | Le job aurait alors un chemin vers l'hyperviseur. |

## Conséquences

- La preuve a été jouée sur le CT 108. Essai n° 3, commit `4ce9657`, verte en 2 s. Le 107 est resté en service.
- Choix du 7 nov. : retirer 108 et garder le récit sur 107. `pct destroy 108 --purge`. Relancer le playbook recréerait le 108.
- La phase 8 reprend ce moule, un LXC à la fois, essai d'abord. Navidrome, 8 nov. : CT 109 `navidrome-essai` `<ip-navidrome-ct109>/24`, créé par le playbook. Réponse locale HTTP 200 ou 302, deuxième passe sans changement. Puis retiré (`pct stop 109`, `pct destroy 109 --purge`). Le récit reste sur le 106. Relancer le playbook recréerait le 109. Jellyfin, 8 nov. : CT 110 `jellyfin-essai` `<ip-jellyfin-ct110>/24`. `/health` à `Healthy`, deuxième passe sans changement. Le 103 est resté en service. Le paquet 12.4 publié aujourd'hui dépend de `jellyfin-ffmpeg8` **8.1.3-2-trixie** ; le 103 a encore `jellyfin-ffmpeg7`. Puis retiré (`pct stop 110`, `pct destroy 110 --purge`). Le récit reste sur le 103. Relancer le playbook recréerait le 110. Samba, 8 nov. : CT 111 `samba-essai` `<ip-samba-ct111>/24`. `smbd` actif, `nmbd` arrêté, écriture refusée, deuxième passe sans changement. Le 102 est resté en service et continue d'écrire. L'essai monte les cinq dossiers en lecture seule. Pas de mot de passe Samba. Puis retiré (`pct stop 111`, `pct destroy 111 --purge`). Le récit reste sur le 102. Relancer le playbook recréerait le 111. servarr, 8 nov. : CT 112 `servarr-essai` `<ip-servarr-ct112>/24`. Pages locales HTTP 200 ou 302, écriture refusée, deuxième passe sans changement. Le 105 est resté en service et continue d'écrire. L'essai monte `/tank/mediatheques` en lecture seule. Pas de clé d'API, pas de `recyclarr sync`. Recyclarr reste un binaire, sans unité. Le pare-feu reprend les quatre ports du 105. Puis retiré (`pct stop 112`, `pct destroy 112 --purge`). Le récit reste sur le 105. Relancer le playbook recréerait le 112. qBittorrent, 8 nov. : CT 113 `qbittorrent-essai` `<ip-qbittorrent-ct113>/24`. Page locale, écriture refusée, sortie du compte coupée (`000`), root sort encore (`301`), deuxième passe sans changement. Le 104 est resté en service, écrit, et garde la clé Proton. L'essai monte les téléchargements en lecture seule, crée sa propre clé WireGuard vers `192.0.2.1`, et laisse `proton-port` arrêté. Puis retiré (`pct stop 113`, `pct destroy 113 --purge`). Le récit reste sur le 104. Relancer le playbook recréerait le 113. Cloudflare, 8 nov. : CT 114 `cloudflare-essai` `<ip-cloudflare-ct114>/24`. cloudflared **2026.10.7** arrêté et désactivé, deuxième passe sans changement. Le 100 est resté en service, encore en **2026.10.4**, avec son jeton. L'essai n'a pas ce jeton. Pas de fichier de pare-feu, pas de nesting, démarrage `order=1,up=30`. Puis retiré (`pct stop 114`, `pct destroy 114 --purge`). Le récit reste sur le 100. Relancer le playbook recréerait le 114. Le montage de `tank` en lecture seule est posé par `pct` sur `pve` : l'API refuse un bind mount à un jeton.
- Jeton d'API Proxmox et jeton d'enregistrement Gitea : `infrastructure/ansible/secrets.yml`, hors du dépôt.
