# Forge Git

> Phase 3 : [FeuilleDeRoute.md](FeuilleDeRoute.md#phase-3--forge-git-et-cicd). Décision du 3 nov. 2026 : **Gitea**, édition libre.

Relevé le 3 nov. 2026. Les numéros de version ne se comparent pas entre eux : chaque projet a sa propre suite.

---

# Décision

Gitea, édition libre. Enterprise n'est pas retenu.

Le but est un workflow professionnel : les gestes qu'on montre quand la forge de référence en entreprise est GitHub. Un dépôt, une demande de fusion, une protection de branche, un workflow Actions, un runner à part, puis un déploiement repris par Argo CD. GitLab a son propre fichier de CI. Ce n'est pas la cible.

L'hébergement visé reste un pod sur `k3s-01`, une réplique, SQLite, un zvol à part sous `tank/vmdata`. Le volume `tank/vmdata/vm-101-gitea-data` (8 Go, `scsi2`) est en ext4, étiquette `gitea-data`, UUID `<uuid-disque-gitea>`, monté sur `/var/lib/k3s-storage/gitea`. Le nom de disque constaté est `/dev/sdc` ; `fstab` porte l'UUID. 7,4 Go libres. Le coffre n'a pas bougé. Ce zvol n'est pas dans le script de snapshots du coffre. Les manifestes sont dans `kubernetes/gitea`, image `docker.gitea.com/gitea:28.3.0`, HTTP seul, inscription fermée. Pas d'Ingress : le nom public n'est pas choisi. L'Application Argo est en sync manuel. Le 3 nov., le pod est `1/1`, le PVC est lié, `INSTALL_LOCK` est vrai, l'inscription est fermée, la lecture des pages demande un compte. Un compte `admin`. Décision du 4 nov. : Argo CD lit GitHub. Le dépôt `homelab` reste sur GitHub seul. Les futures applications se poussent sur Gitea, puis un miroir vers un dépôt GitHub déjà créé, et Argo déploie cette copie. Joué le 4 nov. sur `essai-miroir` : le commit `e2e0eb6a` est le même sur Gitea et sur GitHub. Le dépôt d'essai `admin/homelab` du 3 nov. est encore sur Gitea (`ad9faf2`). Il n'est pas suivi. On le retire quand l'accès extérieur sera en place. L'adresse est `http://<ip-k3s-01>:3000/`. Le 4 nov., le Service est `LoadBalancer` : depuis `pve`, cette adresse répond `200` sans port-forward. Le 3 nov., `SECRET_KEY` était vide : une clé propre à l'instance a été écrite, 64 caractères, sans la noter ici. Archive utile : `/home/utilisateur/backups/gitea/gitea-2026-11-03_180902.tar`, mode 600, SHA-256 `<empreinte-vérifiée>`. Relue ailleurs, base `ok`, compte `admin`, zéro dépôt. Elle est sur le disque système de `k3s-01`, pas encore sur `pve`. L'archive de 18 h 05 reste, sans cette clé. Jalons : [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea).

Le runner reste hors de `k3s-01`. Deux règles. Un service sort du cluster quand il doit lire `tank` sans NFS. Le runner en sort parce que son job exécute le script que le dépôt vient de pousser, et que ce script ne doit pas voir le coffre.

Un pod atterrirait sur `k3s-01`, le seul nœud. Cette VM monte le coffre et la forge : `/var/lib/k3s-storage/vaultwarden` et `/var/lib/k3s-storage/gitea`. Les trois façons de lancer un job y arrivent. En mode machine, le job est un processus sur l'hôte. Avec Docker, le socket du moteur donne la main sur le nœud, donc sur ces dossiers et sur `/etc/rancher/k3s/k3s.yaml`. Avec Kubernetes, le job crée des pods dans le même cluster, et un workflow peut demander un volume `hostPath` vers ces chemins.

Le conteneur retenu est non privilégié. Il n'a pas ces montages, ni le fichier d'accès au cluster. Un job qui dérape remplit ce conteneur. `k3s-01` a 8 Gio pour le coffre, Argo CD, Traefik et Gitea. Le conteneur a son propre plafond, 2 Gio.

Constat du 4 nov. : CT 107, nom `runner`, `<ip-runner>/24`, passerelle `<ip-box>`, non privilégié, `nesting=1`, 2048 Mio, échange 512, 2 cœurs, disque `local-zfs` 16 Go, démarrage automatique, sans montage média. `pct status` : `running`. `curl` a été ajouté. Depuis le CT, `http://<ip-k3s-01>:3000/` répond `200`. Binaire `/usr/local/bin/gitea-runner`, `v5.2.0`, checksum `OK`, 17 744 032 octets. Le shell de `pct exec` a `PATH=/sbin:/bin:/usr/sbin:/usr/bin`, sans `/usr/local/bin`. Compte `gitea-runner`, uid 999. Configuration `/etc/gitea-runner/config.yaml`, mode 600. Enregistré le 4 nov. auprès de `http://<ip-k3s-01>:3000/`, étiquette `host`. Service `gitea-runner` activé au démarrage, `active` à 09:51:45 UTC. Le journal dit `declare successfully`, libellés `[host]`. Le fichier `.runner` est passé de 644 à 600, propriétaire `gitea-runner`. La page Runners le montre : id 1, type global, libellé `host`, statut Idle, dernière connexion `now`. Jalon coché. Le même jour, `admin/essai-miroir` a les Actions activées. Le workflow `.gitea/workflows/ci.yaml` construit puis teste, étiquette `host`. CI n° 1, commit `0813dcc290`, branche `main`, vert en 2 s. Pas `homelab`. Jalon coché.

Une page maison devant `agent`, ouverte depuis le téléphone, viendra après la forge. [FeuilleDeRoute.md](FeuilleDeRoute.md#page-agent-plus-tard).

La comparaison qui suit est le relevé d'avant ce choix. Chaque critère, pris seul, ne tranchait pas.

---

# Maintenance et gouvernance

Les deux projets publient. Aucun n'est arrêté.

## Gitea

Version **28.3.0**, publiée le 1er nov. 2026. La précédente, **28.2.0**, date du 18 oct. 2026. Source : [blog Gitea](https://blog.gitea.com/release-of-28.3.0/), [releases GitHub](https://github.com/go-gitea/gitea/releases/).

Le code publié est sous **MIT**. Fichier `LICENSE` à la racine du dépôt `go-gitea/gitea`, relevé le 3 nov. 2026.

Depuis début 2023, le comité technique (TOC) a six sièges. Trois sont élus pour un an par les mainteneurs qui ne sont pas liés à la société. Trois sont nommés par la société. Le vote d'un élu compte un peu plus que celui d'un nommé. Mandat en cours, du 14 juin au 31 déc. 2026 : élus bircni, delvh, TheFox0x7 ; nommés Yu Tian, Lunny Xiao, Matti Ranta. Source : [community-governance.md](https://github.com/go-gitea/gitea/blob/main/docs/community-governance.md), [élection 2026](https://blog.gitea.com/toc-election-2026/).

Le nom et les domaines sont du côté de la société depuis octobre 2022. Une offre payante, Gitea Enterprise, est portée par CommitGo, à côté du projet. Le projet dit que sa charte interdit d'y mettre du code propriétaire. Source : [annonce Enterprise](https://blog.gitea.com/gitea-enterprise/).

## Forgejo

Forgejo date d'octobre 2022, au moment du transfert du nom Gitea à la société. Les domaines Forgejo sont détenus par **Codeberg e.V.**, association à but non lucratif enregistrée à Berlin. La gouvernance du logiciel est celle des contributeurs, dans un dépôt à part, compatible avec les statuts de l'association. Source : [gouvernance](https://forgejo.org/docs/latest/contributor/governance/), [FAQ](https://forgejo.org/faq/).

Fork dur début 2024. Jusqu'à la 1.21, une installation Gitea passait à Forgejo en changeant le binaire. Ce n'est plus garanti ensuite. L'API vise à rester compatible. Les correctifs Gitea peuvent encore être repris, au cas par cas. L'inverse ne se fait pas. Source : [annonce du fork dur](https://forgejo.org/2024-02-forking-forward/), [comparaison](https://forgejo.org/compare-to-gitea/).

Licence : **GPL-3.0-or-later** à partir de la v9. Jusqu'à la v8 incluse, MIT. Source : [FAQ](https://forgejo.org/faq/).

Versions au 26 oct. 2026 : stable **17.0.1**, suivie jusqu'au 28 janv. 2027 ; LTS **15.0.11**, suivie jusqu'au 15 juil. 2027. Un calendrier de versions est publié. Les annonces de sécurité sont publiques. Source : [releases](https://forgejo.org/releases/).

L'argent vient de dons, de subventions, de bénévoles et de mises à disposition. Source : [FAQ](https://forgejo.org/faq/).

## Ce que ça change ici

Le risque utile pour ce homelab est de savoir qui peut changer le nom, la licence ou le rythme des versions.

Côté Gitea, la société tient le nom et la moitié du comité. L'autre moitié est élue, avec un vote un peu plus lourd. Le code publié reste MIT, et une offre payante vit à côté.

Côté Forgejo, l'association tient le nom. Les contributeurs tranchent. La licence a déjà changé, de MIT à GPL, à la v9. Les deux codes divergent depuis le fork dur : changer d'avis plus tard n'est pas un remplacement de binaire.

Ce critère ne choisit pas.

La page de comparaison de Forgejo affirme en plus une cession de droits, un modèle open core et des correctifs de sécurité annoncés d'abord aux clients. Ce n'est pas repris ici comme un fait : le `LICENSE` Gitea relevé est MIT, et l'offre entreprise est décrite par Gitea comme hors du projet.

---

# Fonctions Git

Issues, demandes de fusion, releases, wiki, projets et registre de paquets sont dans les deux. Pour ce homelab, ce critère ne les sépare pas.

## Commun

Le dépôt a le code, les issues, les demandes de fusion, les releases, le wiki et les tableaux. Les droits d'équipe se règlent par unité. Forgejo liste : code, issues, demandes de fusion, releases, wiki, projets, paquets, Actions. Source : [permissions Forgejo](https://forgejo.org/docs/latest/user/collaboration/repo-permissions/).

Le registre de paquets appartient à un utilisateur ou à une organisation, et peut être lié à un dépôt. Les deux annoncent Alpine, Arch, Cargo, Chef, Composer, Conan, Conda, conteneurs OCI, CRAN, Debian, un format générique, Go, Helm, Maven, npm, NuGet, Pub, PyPI, RPM, RubyGems, Swift et Vagrant. Gitea ajoute Terraform, et `zypper` pour le RPM. Forgejo ajoute ALT (`apt-rpm`). Sources : [registre Gitea](https://docs.gitea.com/usage/packages/overview/), [registre Forgejo 17.0](https://forgejo.org/docs/v17.0/user/packages/).

Gitea envoie des webhooks au niveau du dépôt, de l'organisation, de l'utilisateur et de l'instance. Événements documentés : push, issues, demandes de fusion, releases, paquets. Cibles documentées : Slack, Discord, Matrix, Telegram, Teams, et d'autres. Signature HMAC. Source : [webhooks Gitea](https://docs.gitea.com/usage/repository/webhooks/).

La 28.0 de Gitea ajoute des règles d'approbation par propriétaires de code, des comptes bot et un journal d'audit. Source : [annonce 28.0.0](https://blog.gitea.com/release-of-28.0.0/). La 17.0 de Forgejo ajoute la complétion des issues et des demandes de fusion. Source : [annonce 17.0](https://forgejo.org/2026-10-release-v17-0/).

## Ce que ça change ici

Un dépôt personnel, des issues et des releases suffisent. Un registre OCI ou générique est là des deux côtés si une image privée devient utile plus tard. Rien dans cette liste ne contredit la piste Gitea, et rien ne l'impose.

---

# CI

Les deux ont une CI intégrée. Le logiciel de la forge ne lance pas les jobs. Un runner, ailleurs, les prend et renvoie les journaux.

## Gitea

Actions est activé sur l'instance depuis la 1.21. Chaque dépôt le laisse éteint tant qu'on ne l'active pas. Les workflows sont des YAML dans `.gitea/workflows/`. La syntaxe vise la compatibilité GitHub Actions. Source : [démarrage](https://docs.gitea.com/usage/actions/quickstart/).

Le runner est un logiciel à part, série **5.x**, binaire `gitea-runner`. Il s'enregistre avec un jeton, valable pour l'instance, une organisation ou un dépôt. Un runner éphémère prend un seul job, puis ses identifiants sont révoqués. Source : [runner](https://docs.gitea.com/runner/), [enregistrement](https://docs.gitea.com/runner/4/registration/).

L'étiquette du runner dit où le job tourne : conteneur Docker ou Podman, pod Kubernetes, ou la machine du runner. La doc dit de réserver la machine du runner aux dépôts de confiance. Source : [étiquettes](https://docs.gitea.com/runner/labels/).

Les secrets sont au niveau utilisateur, organisation ou dépôt. Dans le workflow : `${{ secrets.NOM }}`. Le dépôt l'emporte sur l'organisation. Les noms ne commencent ni par `GITEA_` ni par `GITHUB_`. Source : [secrets](https://docs.gitea.com/usage/actions/secrets/).

## Forgejo

Même découpage. Workflows dans `.forgejo/workflows/`. S'il n'y a pas ce dossier, Forgejo lit `.github/workflows/`. La doc dit que c'est familier pour qui vient de GitHub Actions, et que ce n'est pas conçu pour être compatible : un workflow GitHub demande en général un ajustement. Source : [vue d'ensemble](https://forgejo.org/docs/v17.0/user/actions/overview/).

Le runner a trois modes : Docker ou Podman, LXC, ou la machine du runner. Le mode machine n'isole rien. Un job peut lire le fichier d'enregistrement du runner. Source : [configuration](https://forgejo.org/docs/v17.0/admin/actions/configuration/), [sécurité](https://forgejo.org/docs/v17.0/admin/actions/security/).

Les secrets sont chiffrés en base, aux niveaux organisation, utilisateur et dépôt. Une fois enregistrés, la valeur ne se réaffiche pas. Déclencheurs documentés : push, issues, demandes de fusion, releases. Une demande de fusion venue d'un fork n'a pas les secrets, et son jeton est en lecture. Source : [concepts](https://forgejo.org/docs/v17.0/user/actions/basic-concepts/), [référence](https://forgejo.org/docs/latest/user/actions/reference/).

Un audit du runner a eu lieu fin 2024. Les problèmes trouvés ont été corrigés en 2025. Source : [vue d'ensemble](https://forgejo.org/docs/v17.0/user/actions/overview/).

## Ce que ça change ici

Le runner ne se pose pas sur `k3s-01` : Vaultwarden y tourne, et la forge y est visée. Un job en mode machine, ou un pod Kubernetes sur ce nœud, lirait la même machine. Le détail tenu le 4 nov. est dans la [décision](#décision) : LXC 107, sans les disques du coffre ni de la forge.

Gitea documente Docker, Kubernetes et la machine. Forgejo documente Docker, LXC et la machine. LXC est le mode déjà utilisé ici pour les services. Kubernetes pointerait vers le nœud qui porte le coffre.

La piste reste Gitea. Ce critère donne un argument au runner Forgejo, pas un choix.

---

# Déploiement

Les deux sont un seul processus. La base, les dépôts et le fichier `app.ini` vivent sur le disque. Une mise à jour remplace le binaire ou l'image. Au démarrage, le processus migre la base. Aucun des deux ne fournit de commande de restauration.

## Gitea

Chemins documentés : binaire, Docker (`docker.gitea.com/gitea`, une étiquette de version comme `28.3.0`), paquet, et Kubernetes par le chart Helm `gitea-charts` (`https://dl.gitea.com/charts/`). Sans autre base, l'exemple Docker initialise SQLite. Sources : [binaire](https://docs.gitea.com/installation/install-from-binary/), [Docker](https://docs.gitea.com/installation/install-with-docker/), [Kubernetes](https://docs.gitea.com/installation/install-on-kubernetes).

Mise à jour : arrêter, sauvegarder, remplacer, redémarrer. Deux versions qui partagent les deux premiers numéros (`28.3.0` et `28.3.1`) gardent la même structure de base. Changer le second numéro migre la base : l'ancien binaire ne démarre plus dessus. Le retour passe par la sauvegarde. Source : [mise à jour](https://docs.gitea.com/installation/upgrade-from-gitea).

Sauvegarde : la doc demande d'arrêter l'instance. `gitea dump` produit un zip (dépôts, répertoire `data/`, `app.ini`, un SQL). On remet les fichiers à la main. Le SQL produit par l'outil interne a des problèmes ouverts pour MySQL et PostgreSQL. `SECRET_KEY`, dans `app.ini`, chiffre des valeurs. La doc prend le secret 2FA comme exemple : le perdre rend ces valeurs illisibles. Sources : [sauvegarde](https://docs.gitea.com/administration/backup-and-restore), [configuration](https://docs.gitea.com/administration/config-cheat-sheet/).

Un push mirror vers GitHub écrase la copie distante. Le dépôt GitHub doit déjà exister. Source : [miroirs](https://docs.gitea.com/usage/repository/repo-mirror/).

## Forgejo

La page d'installation retient deux méthodes reprises à chaque version : le binaire, et Docker (`codeberg.org/forgejo/forgejo:17` ; l'étiquette `17` suit les correctifs de la 17). Le reste est du packaging tiers. Un chart Helm est publié en `oci://code.forgejo.org/forgejo-helm/forgejo`. Son numéro ne suit pas celui du logiciel. Sources : [installation](https://forgejo.org/docs/latest/admin/installation/), [Docker](https://forgejo.org/docs/latest/admin/installation/docker/).

Mise à jour : sauvegarde complète exigée pour une nouvelle version stable, prudente aussi pour un correctif. On peut viser directement la dernière version publiée. Les notes de chaque version intermédiaire se lisent quand même : un changement du premier numéro peut demander une intervention. La base refuse un retour en arrière. Depuis la 7.0.0, le projet suit le versionnement sémantique. Stable suivie trois mois, LTS un an et trois mois. Source : [mise à jour](https://forgejo.org/docs/latest/admin/upgrade/).

Le guide décrit encore un passage depuis Gitea, jusqu'à la **1.22** incluse, en deux temps : Gitea 1.22 vers Forgejo 10, puis Forgejo 10 vers une version plus récente. Source : [mise à jour](https://forgejo.org/docs/latest/admin/upgrade/).

Sauvegarde : arrêter. Avec SQLite et la configuration par défaut, copier le dossier `data` couvre la base, les dépôts, les fichiers, les files et les index. `app.ini` vient avec. `SECRET_KEY` déchiffre, entre autres, les identifiants de miroir et les secrets Actions. `JWT_SECRET` signe les jetons OAuth. Les perdre oblige à les recréer. La restauration remet la base, les fichiers et `app.ini`, puis démarre. Source : [sauvegarde](https://forgejo.org/docs/latest/admin/setup/backup/).

Un push mirror vers GitHub écrase aussi la copie distante. Le dépôt GitHub doit déjà exister. Source : [miroirs](https://forgejo.org/docs/latest/user/repo-mirror/).

## Ce que ça change ici

La forge est visée sur `k3s-01`, un pod, une réplique, SQLite. Les données vont sur un zvol à part, sous `tank/vmdata`. Le disque système (64 Go) et le zvol Vaultwarden ne les portent pas. Les manifests de ce pod restent dans le dépôt GitHub que Argo CD clone déjà (`git@github.com:TLGitDev/homelab.git`). La forge ne devient pas la seule copie de sa propre définition.

La sauvegarde utile est celle du dossier de données, instance arrêtée, comme pour Vaultwarden. Elle contient `SECRET_KEY` et le jeton du miroir. Le miroir GitHub ne copie que les dépôts Git, et il écrase ce qui aurait été commité là-bas. Il ne remplace pas cette sauvegarde. Joué le 3 nov. : archive `gitea-2026-11-03_180902.tar` sur `k3s-01`, relue ailleurs. [FeuilleDeRoute.md](FeuilleDeRoute.md#jalons-gitea).

Le runner reste hors de `k3s-01`. Il pousse le manifeste vers la forge. Le miroir met à jour GitHub. Argo CD applique depuis cette copie.

Gitea 28.3.0 est au-delà du passage documenté vers Forgejo, qui s'arrête à Gitea 1.22. Installer la piste actuelle ferme cette porte. Les deux images tiennent dans le même pod et le même volume. Ce critère ne choisit pas.

La piste reste Gitea. Pas de choix.

---

# Écosystème

Aucun des deux ne documente un système de plugins. L'extension passe par l'API, les webhooks, les thèmes et des outils à côté. Le client qui pousse le code reste Git.

## Gitea

La documentation est un seul jeu courant, sur [docs.gitea.com](https://docs.gitea.com/). La page des intégrations renvoie à la liste tenue par le projet, [awesome-gitea](https://gitea.com/gitea/awesome-gitea) : thèmes, intégrations d'IDE, outils. Source : [intégrations](https://docs.gitea.com/development/integrations/).

Les thèmes livrés sont `gitea-light`, `gitea-dark` et `gitea-auto`. Un thème en plus est un fichier `theme-<nom>.css` dans le répertoire custom, déclaré dans `THEMES`. Source : [personnalisation](https://docs.gitea.com/administration/customizing-gitea/).

Le client en ligne de commande s'appelle `gt`. La 1.0.0, publiée le 2 nov. 2026, remplace `tea`, dont le dépôt est archivé. `gt` parle à Gitea 28 et aux versions plus récentes. Il sert aux issues, aux demandes de fusion, aux runners et aux dépôts. Source : [annonce](https://blog.gitea.com/release-of-gitea-cli-1.0.0/).

Le forum est [forum.gitea.com](https://forum.gitea.com/). Des sujets y portent la date du 2 nov. 2026.

## Forgejo

La documentation est versionnée. Les pages de la 17 sont sous `/docs/v17.0/`, et `/docs/latest/` suit la branche en cours. L'API d'une même version majeure reste compatible. Un changement du premier numéro peut la casser, et les notes de version le disent. La référence est générée sur l'instance, à `/api/swagger`. Source : [usage de l'API](https://forgejo.org/docs/v17.0/user/api/usage/).

Le numéro affiché a la forme `X.Y.Z+gitea-A.B.C`. La partie après `+gitea-` est la version Gitea dont les outils restent utilisables. La page de la 17 donne l'exemple `7.0.0+gitea-1.22.0` et écrit que les outils prévus pour Gitea 1.22 et avant n'ont pas à changer. Source : [numérotation](https://forgejo.org/docs/v17.0/user/api/versions/).

Les thèmes livrés couvrent clair, sombre, auto, les anciens thèmes Gitea, et des variantes pour daltonisme. Les modèles de pages copiés dans le répertoire custom sont possibles. La doc les dit non pris en charge : une mise à jour peut les casser sans prévenir. Source : [personnalisation](https://forgejo.org/docs/latest/admin/advanced/customization/), [configuration](https://forgejo.org/docs/v17.0/admin/config-cheat-sheet/).

Les bugs et les demandes vont sur le suivi du projet. Le reste se discute dans un salon Matrix, indiqué dans le pied des pages. Les avis de sécurité vont à `security@forgejo.org`. Source : [discussions](https://forgejo.org/docs/latest/contributor/discussions/).

Une liste tenue à part, [Delightful Forgejo](https://codeberg.org/forgejo-contrib/delightful-forgejo/), recense clients, thèmes, CI et documentation. Elle dit que la documentation Gitea reste en grande partie utilisable. Codeberg est l'instance publique portée par l'association.

## Ce que ça change ici

Le PC pousse avec Git. Le téléphone ouvre l'application déjà déployée, par le tunnel. Ni un thème, ni un plugin, ni un client mobile de la forge n'entrent dans ce parcours.

`gt` est un outil en plus, du côté Gitea 28. La page Forgejo 17 décrit encore la compatibilité des outils Gitea au niveau 1.22. Ça ne contredit pas la piste, et ça n'oblige pas à s'en servir.

Les deux documentations ont suffi à remplir les critères précédents. Ce critère ne choisit pas.

La piste reste Gitea. Pas de choix.

---

# Coût opérationnel

Le logiciel des deux côtés s'installe sans abonnement. Le coût dans ce homelab est la mémoire de `k3s-01`, le disque des dépôts, et le temps d'une mise à jour.

## Gitea

La doc dit qu'un Raspberry Pi 3 suffit pour une petite charge, et que 2 cœurs et 1 Go de RAM suffisent en général pour une petite équipe. Git 2.0 ou plus récent est requis. Source : [présentation](https://docs.gitea.com/).

SQLite est livré avec le binaire. La doc dit qu'il ne tient pas la charge, et qu'il vaut mieux choisir la base définitive à l'installation. Changer ensuite n'est pas un chemin bien essayé. Source : [préparation de la base](https://docs.gitea.com/installation/database-prep/).

L'édition publiée est gratuite : dépôts, issues, demandes de fusion, Actions, paquets. Une édition Enterprise, à côté du projet, est affichée à 9,50 $ par utilisateur et par mois, avec un an d'engagement. La page barre 19 $. Elle ajoute notamment SAML, une liste d'adresses IP et un support avec délai garanti. Source : [tarifs](https://about.gitea.com/pricing/), relevé le 3 nov. 2026.

Les versions se suivent de près. La 28.2.0 date du 18 oct. 2026, la 28.3.0 du 1er nov.

## Forgejo

La page d'installation ne publie pas de minimum en mémoire ou en cœurs. Sans autre base, l'image Docker prend SQLite. Pour une activité faible ou moyenne, la doc recommande SQLite : un à trois fichiers, sans entretien, à part un `VACUUM` si le fichier grossit après des effacements. Une forte concurrence oriente vers MySQL ou PostgreSQL. Passer de l'un à l'autre ensuite n'est pas anodin. Sources : [Docker](https://forgejo.org/docs/latest/admin/installation/docker/), [recommandations](https://forgejo.org/docs/latest/admin/setup/recommendations/), [préparation](https://forgejo.org/docs/latest/admin/installation/database-preparation/).

Pas d'édition payante. L'argent du projet vient de dons, de subventions et de mises à disposition. Source : [FAQ](https://forgejo.org/faq/).

Le calendrier publié espace les versions stables de trois mois. Une LTS, au premier trimestre, est suivie un an et trois mois. La 15.0 l'est jusqu'au 15 juil. 2027. La 17.0, qui n'est pas LTS, jusqu'au 28 janv. 2027. Source : [versions](https://forgejo.org/releases/).

## Ce que ça change ici

Une personne, quelques dépôts, SQLite. Pas de second pod pour une base. Enterprise ne sert à rien ici : l'accès « moi seul » est déjà Access, devant le tunnel. Le miroir réutilise le compte GitHub déjà en place.

`k3s-01` a 8 Gio attribués. Constat du 3 nov. dans la VM : 7,5 Gio vus, 5,5 Gio disponibles, 4 cœurs, échange inutilisé. Le disque système a 51 Go libres. Le 1 Go cité par Gitea vise une petite équipe. La marge y est. Le disque des dépôts est le zvol `tank/vmdata/vm-101-gitea-data`, 8 Go, monté. Au formatage : 7,4 Go libres.

Le geste d'entretien est le même : arrêter, copier le dossier de données, remplacer l'image, relancer. Forgejo publie un calendrier et une LTS, donc moins de passages si on reste sur la 15. Gitea publie plus souvent. Le runner, plus tard et hors de cette VM, coûtera le CPU des builds. Il est le même fardeau des deux côtés.

Ce critère ne choisit pas. La piste reste Gitea.

Les six critères sont examinés. Le choix est pris ensuite : [Décision](#décision).
