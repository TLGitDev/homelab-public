# ADR-014 — Noms et HTTPS sur le LAN

## Statut

Accepté et appliqué le 12 nov. 2026. Le numéro 013 reste réservé à l'isolement des applications maison exposées sur Internet.

## Contexte

Jusqu'au 12 nov. 2026, les services du homelab se joignaient par `IP:port`, en HTTP pour la plupart. Proxmox et le Traefik de K3s présentaient un certificat auto-signé, qui déclenche une alerte dans le navigateur.

Le jalon de la phase 9 demandait trois choses :

- un nom stable par service ;
- un certificat valide, obtenu par défi DNS-01 auprès de Cloudflare ;
- un accès identique depuis le LAN et depuis le téléphone par WireGuard.

Deux questions restaient ouvertes : **qui résout les noms**, et **qui porte les certificats**.

Trois contraintes pèsent sur la première question :

- Le PC fixe a Proton VPN actif en permanence. Le DNS qu'il utilise est celui de Proton (`10.2.0.1`), pas celui de la box.
- Le téléphone bascule entre deux tunnels de l'application WireGuard, l'un vers Proton, l'autre vers le homelab. Le réglage Android « Bloquer les connexions sans VPN » est actif.
- La box permet de changer le DNS distribué en DHCP sur le LAN.

## Décision

1. **Les noms** sont de la forme `<service>.lan.labo.example`. Ils sont résolus par **un seul enregistrement public** chez Cloudflare : `*.lan.labo.example`, de type `A`, vers `<ip-lan>`, en mode « DNS only ».
2. **Les certificats** sont portés par un **conteneur LXC dédié**, le CT 116 `lan` (`<ip-lan>`). Il fait tourner Traefik en binaire, sans Kubernetes. Traefik obtient un certificat joker `*.lan.labo.example` par défi DNS-01, avec un jeton Cloudflare limité à la zone `labo.example`. Le conteneur est décrit en Ansible ([ADR-010](ADR-010-Ansible-LXC.md)).
3. **Le téléphone, par WireGuard**, résout les noms avec dnsmasq, qui écoute sur le CT 115 à l'adresse du tunnel (`<ip-wg-serveur>`). Le tunnel du téléphone envoie tout son trafic vers le 115 (`AllowedIPs = 0.0.0.0/0`). Le filtre du 115 reste seul juge des destinations autorisées.

## Raisons

- **Le joker public fonctionne avec tous les résolveurs.** Proton, la box, `1.1.1.1` et dnsmasq le résolvent tous. Le 12 nov., Proton et la box ont tous deux répondu `<ip-lan>`. Aucun ne jette les réponses en adresse privée.
- **Un DNS interne distribué par la box aurait raté sa cible.** Le PC passe par le DNS de Proton et ne l'aurait jamais interrogé. Il aurait aussi rendu tout l'accès à Internet de la maison dépendant du CT 116.
- **Un conteneur dédié garde les noms indépendants de K3s.** Si `k3s-01` s'arrête, Proxmox, Jellyfin et les autres restent joignables par leur nom. Le flux des médias ne traverse pas la VM qui porte le coffre, ce que l'[ADR-012](ADR-012-LXC-ou-K3s.md) cherche à éviter.
- **Traefik est déjà connu.** C'est le même outil que dans K3s. Il gère le défi Cloudflare sans module à compiler.
- **Un certificat joker ne liste pas les services.** Les journaux publics de transparence des certificats ne montrent que `*.lan.labo.example`.
- **Le DNS du téléphone doit passer dans le tunnel.** Le coupe-circuit d'Android bloque tout trafic qui sort hors du VPN actif. Un DNS public déclaré dans le tunnel ne répond donc jamais.
- **Le tunnel doit servir de route par défaut.** Sans elle, Firefox 160 ne résout aucun nom, alors que Vanadium, `curl` et `ping` y arrivent. Avec `0.0.0.0/0`, tout fonctionne. Le filtre du 115 jette ce qui n'est pas listé : le tunnel ne donne pas accès à Internet.

## Alternatives étudiées

| Alternative | Pourquoi elle n'est pas retenue |
| --- | --- |
| DNS interne (dnsmasq) distribué par la box | Le PC et le téléphone sous Proton ne l'interrogent pas. Toute la maison dépendrait du CT 116 pour résoudre les noms |
| Traefik de K3s avec cert-manager | Tout le trafic, streaming compris, traverserait `k3s-01`. Une panne de la VM couperait tous les noms |
| Un certificat par service | Chaque nom de service apparaîtrait dans les journaux publics de certificats |
| Tunnel du téléphone limité aux adresses du LAN | Firefox ne résout aucun nom. Il aurait fallu aussi tenir à jour la liste sur le téléphone à chaque nouveau service |
| Désactiver « Bloquer les connexions sans VPN » | Proton perdrait son coupe-circuit, avec un risque de fuite quand on change de tunnel |

## Conséquences

- **Une adresse privée devient publique** : `<ip-lan>` apparaît dans le DNS public. Elle n'est pas joignable depuis Internet.
- **Un nouveau secret existe** : le jeton Cloudflare `DNS:Edit` sur la zone. Il vit dans `secrets.yml`, ignoré par Git, et dans `/etc/traefik/traefik.env` (mode 0600) sur le CT 116. Il est à ranger dans Vaultwarden.
- **Le CT 116 devient un point de passage** pour les noms. Les adresses `IP:port` restent valables en secours.
- **Le tunnel homelab du téléphone ne donne pas accès à Internet.** On bascule sur le tunnel Proton pour le reste.
- **Ajouter un service** demande une ligne dans `lan_services` (`vars/lan.yml`), et une destination dans `acces_destinations` s'il doit être joignable par WireGuard. Rien ne change sur le téléphone.
- **Le renouvellement est automatique.** Traefik renouvelle le certificat 30 jours avant son expiration. Aucune alerte ne signale encore un échec : c'est à prévoir avec l'observabilité (phase 15).

## Quand revoir cette décision

- Si un résolveur utilisé dans la maison se met à jeter les réponses en adresse privée.
- Si le PC abandonne Proton VPN : un DNS interne redeviendrait possible, sans rien publier.
- Si le cluster passe à plusieurs nœuds, ou si un équilibreur de charge apparaît.
