# ADR-010 — Les LXC d'infra en Ansible

## Statut

Accepté le 2026-11-07. Le playbook est dans le dépôt (`c1a1e07`). Il n'a pas été lancé. Le CT 108 n'existe pas.

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

- La preuve se fait sur le CT 108. Le 107 reste en service tant que 108 n'a pas pris un workflow vert.
- Ensuite, un des deux : arrêter 107, ou retirer 108 et garder le récit sur 107. Le choix n'est pas fait.
- La phase 8 reprend ce moule, un LXC à la fois, essai d'abord.
- Jeton d'API Proxmox et jeton d'enregistrement Gitea : `infrastructure/ansible/secrets.yml`, hors du dépôt.
