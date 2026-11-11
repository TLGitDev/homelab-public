# ADR-011 — Forge Git : Gitea

## Statut

Accepté le 3 nov. 2026. Mis en œuvre le même jour (pod sur `k3s-01`), puis complété le 4 nov. par le runner (CT 107) et le miroir vers GitHub. Exploitation : [forge-gitea.md](../exploitation/forge-gitea.md).

## Contexte

La phase 3 de la [feuille de route](../FeuilleDeRoute.md) demande une forge Git auto-hébergée. Le but est de pratiquer un workflow professionnel, avec les gestes qu'on montre quand la forge de référence en entreprise est GitHub :

- un dépôt et une demande de fusion ;
- une protection de branche ;
- un workflow de type Actions, exécuté par un runner séparé ;
- un déploiement repris par Argo CD.

GitLab, qui a son propre format de CI, n'est pas la cible. Restent deux candidats proches : **Gitea** et **Forgejo**, un fork de Gitea.

L'hébergement visé est un pod sur `k3s-01`, une réplique, SQLite, avec un zvol dédié sous `tank/vmdata`.

## Décision

**Gitea, édition libre.** L'édition Enterprise n'est pas retenue.

## Raisons

Les deux projets ont été comparés sur six critères, relevés le 3 nov. 2026 (voir l'annexe). **Aucun critère, pris seul, ne tranchait** : sur chacun, la conclusion était « ce critère ne choisit pas, la piste reste Gitea ». Le choix s'est donc fait sur deux raisons, liées à l'objectif de départ :

1. **La CI de Gitea vise la compatibilité de syntaxe avec GitHub Actions.** GitHub Actions est très répandu en entreprise, et le but du homelab est de pratiquer des gestes directement transférables. Forgejo dit au contraire que sa CI n'est pas conçue pour être compatible : un workflow GitHub y demande en général un ajustement.
2. **Le code publié reste sous licence MIT.** C'est la licence la plus simple et la plus permissive. Forgejo, lui, est passé de MIT à GPL-3.0-or-later à la v9.

Les fonctions récentes de Gitea 28 (client `gt`, approbation par propriétaires de code, comptes bot, journal d'audit) vont dans le même sens, mais n'ont pas pesé dans la décision.

## Alternatives étudiées

| Option | Pourquoi elle n'est pas retenue |
| --- | --- |
| Forgejo | Proche sur tous les critères. Gouvernance associative et calendrier avec LTS, ce qui est un vrai avantage. Mais la CI se dit volontairement non compatible avec GitHub Actions, et la licence est passée de MIT à GPL à la v9. Aucun critère ne l'imposait. |
| Gitea Enterprise | Payant (9,50 $ par utilisateur et par mois, avec un an d'engagement). Ses ajouts (SAML, liste d'adresses IP, support garanti) ne servent à rien pour une seule personne. |
| GitLab | Format de CI propre, éloigné de GitHub Actions. Hors cible. |

## Conséquences

- **Plus de retour simple vers Forgejo.** Le passage documenté de Gitea vers Forgejo s'arrête à Gitea 1.22. Installer Gitea 28.3.0 ferme cette porte : changer d'avis demanderait une vraie migration.
- **Le runner tourne hors de `k3s-01`**, dans un LXC non privilégié (CT 107), pour que les jobs ne voient ni le coffre ni la forge. Voir [forge-gitea.md](../exploitation/forge-gitea.md), section 4.
- **Argo CD continue de lire GitHub** (décision du 4 nov.). Le dépôt `homelab` reste sur GitHub seul. Les nouvelles applications passent par Gitea, puis par un miroir vers GitHub.
- **La sauvegarde doit inclure `app.ini`**, et donc `SECRET_KEY` : sans elle, les valeurs chiffrées (secrets 2FA, identifiants de miroir, secrets Actions) deviennent illisibles. Le miroir GitHub ne remplace pas cette sauvegarde.
- **Les mises à jour sont fréquentes** (28.2.0 le 18 oct., 28.3.0 le 1er nov.). Un changement du deuxième numéro de version migre la base sans retour possible, sauf par la sauvegarde.

## Annexe — Comparaison détaillée (relevé du 3 nov. 2026)

Les numéros de version ne se comparent pas d'un projet à l'autre : chacun a sa propre suite.

### 1. Maintenance et gouvernance

Les deux projets publient régulièrement ; aucun n'est arrêté.

| | Gitea | Forgejo |
| --- | --- | --- |
| Dernière version | 28.3.0, le 1er nov. 2026 (28.2.0 le 18 oct.) | Stable 17.0.1, suivie jusqu'au 28 janv. 2027 ; LTS 15.0.11, suivie jusqu'au 15 juil. 2027 (relevé du 26 oct.) |
| Licence | MIT (fichier `LICENSE` du dépôt `go-gitea/gitea`) | GPL-3.0-or-later depuis la v9 ; MIT jusqu'à la v8 incluse |
| Détenteur du nom | La société (CommitGo) depuis octobre 2022 | Codeberg e.V., association à but non lucratif enregistrée à Berlin |
| Gouvernance | Comité technique de six sièges depuis début 2023 : trois élus pour un an par les mainteneurs non liés à la société, trois nommés par la société. Le vote d'un élu pèse un peu plus. Mandat du 14 juin au 31 déc. 2026 : élus bircni, delvh, TheFox0x7 ; nommés Yu Tian, Lunny Xiao, Matti Ranta | Les contributeurs, dans un dépôt à part, compatible avec les statuts de l'association |
| Financement | Offre payante Gitea Enterprise à côté du projet. Le projet dit que sa charte interdit d'y mettre du code propriétaire | Dons, subventions, bénévoles, mises à disposition |

Forgejo est né en octobre 2022, au moment du transfert du nom Gitea à la société. Le fork est devenu « dur » début 2024. Jusqu'à la 1.21, on passait de Gitea à Forgejo en changeant le binaire ; ce n'est plus garanti ensuite. L'API vise à rester compatible. Forgejo peut encore reprendre des correctifs de Gitea au cas par cas, l'inverse ne se fait pas.

La page de comparaison de Forgejo affirme en plus une cession de droits, un modèle *open core* et des correctifs de sécurité annoncés d'abord aux clients payants. Ce n'est pas repris ici comme un fait : le `LICENSE` relevé est MIT, et Gitea décrit son offre entreprise comme extérieure au projet.

**Pour le homelab** : le risque utile est de savoir qui peut changer le nom, la licence ou le rythme des versions. Chez Gitea, la société tient le nom et la moitié du comité, mais le code reste MIT. Chez Forgejo, l'association tient le nom et les contributeurs décident, mais la licence a déjà changé une fois. Les codes divergent depuis le fork dur. Ce critère ne choisit pas.

Sources : [blog Gitea 28.3.0](https://blog.gitea.com/release-of-28.3.0/), [releases Gitea](https://github.com/go-gitea/gitea/releases/), [gouvernance Gitea](https://github.com/go-gitea/gitea/blob/main/docs/community-governance.md), [élection 2026](https://blog.gitea.com/toc-election-2026/), [annonce Enterprise](https://blog.gitea.com/gitea-enterprise/), [gouvernance Forgejo](https://forgejo.org/docs/latest/contributor/governance/), [FAQ Forgejo](https://forgejo.org/faq/), [fork dur](https://forgejo.org/2024-02-forking-forward/), [comparaison Forgejo](https://forgejo.org/compare-to-gitea/), [versions Forgejo](https://forgejo.org/releases/).

### 2. Fonctions Git

Les deux ont les issues, les demandes de fusion, les releases, le wiki, les projets (tableaux) et un registre de paquets. Les droits d'équipe se règlent par unité : code, issues, demandes de fusion, releases, wiki, projets, paquets, Actions.

| | Gitea | Forgejo |
| --- | --- | --- |
| Registre de paquets | Alpine, Arch, Cargo, Chef, Composer, Conan, Conda, conteneurs OCI, CRAN, Debian, générique, Go, Helm, Maven, npm, NuGet, Pub, PyPI, RPM, RubyGems, Swift, Vagrant ; **en plus** Terraform, et `zypper` pour le RPM | La même liste ; **en plus** ALT (`apt-rpm`) |
| Webhooks | Au niveau du dépôt, de l'organisation, de l'utilisateur et de l'instance. Événements : push, issues, demandes de fusion, releases, paquets. Cibles : Slack, Discord, Matrix, Telegram, Teams… Signature HMAC | — |
| Nouveautés récentes | 28.0 : règles d'approbation par propriétaires de code, comptes bot, journal d'audit | 17.0 : complétion des issues et des demandes de fusion |

Le registre appartient à un utilisateur ou à une organisation, et peut être lié à un dépôt.

**Pour le homelab** : un dépôt personnel, des issues et des releases suffisent. Un registre OCI ou générique existe des deux côtés si une image privée devient utile. Ce critère ne choisit pas.

Sources : [permissions Forgejo](https://forgejo.org/docs/latest/user/collaboration/repo-permissions/), [registre Gitea](https://docs.gitea.com/usage/packages/overview/), [registre Forgejo 17.0](https://forgejo.org/docs/v17.0/user/packages/), [webhooks Gitea](https://docs.gitea.com/usage/repository/webhooks/), [Gitea 28.0.0](https://blog.gitea.com/release-of-28.0.0/), [Forgejo 17.0](https://forgejo.org/2026-10-release-v17-0/).

### 3. CI

Dans les deux cas, la forge ne lance pas les jobs elle-même : un runner, installé ailleurs, les prend et renvoie les journaux.

| | Gitea | Forgejo |
| --- | --- | --- |
| Activation | Actions actif sur l'instance depuis la 1.21 ; chaque dépôt reste désactivé tant qu'on ne l'active pas | Même découpage |
| Emplacement des workflows | `.gitea/workflows/` | `.forgejo/workflows/`, ou `.github/workflows/` à défaut |
| Compatibilité GitHub Actions | La syntaxe **vise** la compatibilité | « Familier », mais **pas conçu pour être compatible** : un workflow GitHub demande en général un ajustement |
| Runner | Logiciel à part, série 5.x, binaire `gitea-runner`. Jeton d'enregistrement par instance, organisation ou dépôt. Un runner éphémère prend un seul job, puis ses identifiants sont révoqués | Logiciel à part. Un audit fin 2024, problèmes corrigés en 2025 |
| Modes d'exécution | Docker ou Podman, pod Kubernetes, ou la machine du runner (à réserver aux dépôts de confiance) | Docker ou Podman, LXC, ou la machine du runner (n'isole rien : un job peut lire le fichier d'enregistrement du runner) |
| Secrets | Utilisateur, organisation ou dépôt, `${{ secrets.NOM }}`. Le dépôt l'emporte sur l'organisation. Pas de nom commençant par `GITEA_` ou `GITHUB_` | Chiffrés en base, aux mêmes niveaux, jamais réaffichés. Une demande de fusion venue d'un fork n'a pas les secrets, et son jeton est en lecture seule |

**Pour le homelab** : le runner ne peut pas aller sur `k3s-01`, où tournent Vaultwarden et la forge. Le mode LXC de Forgejo correspond à ce qui est déjà utilisé ici pour les services, et le mode Kubernetes de Gitea pointerait vers le nœud qui porte le coffre. Ce critère donne un argument au runner de Forgejo, pas un choix. La solution retenue est un LXC séparé, avec le runner Gitea en mode machine.

Sources : [démarrage Gitea Actions](https://docs.gitea.com/usage/actions/quickstart/), [runner Gitea](https://docs.gitea.com/runner/), [enregistrement](https://docs.gitea.com/runner/4/registration/), [étiquettes](https://docs.gitea.com/runner/labels/), [secrets Gitea](https://docs.gitea.com/usage/actions/secrets/), [vue d'ensemble Forgejo Actions](https://forgejo.org/docs/v17.0/user/actions/overview/), [configuration du runner](https://forgejo.org/docs/v17.0/admin/actions/configuration/), [sécurité](https://forgejo.org/docs/v17.0/admin/actions/security/), [concepts](https://forgejo.org/docs/v17.0/user/actions/basic-concepts/), [référence](https://forgejo.org/docs/latest/user/actions/reference/).

### 4. Déploiement

Les deux sont un seul processus. La base, les dépôts et `app.ini` vivent sur le disque. Une mise à jour remplace le binaire ou l'image, et le processus migre la base au démarrage. Aucun ne fournit de commande de restauration.

| | Gitea | Forgejo |
| --- | --- | --- |
| Installation | Binaire, Docker (`docker.gitea.com/gitea:28.3.0`), paquet, chart Helm `gitea-charts` (`https://dl.gitea.com/charts/`). L'exemple Docker initialise SQLite | Binaire et Docker (`codeberg.org/forgejo/forgejo:17`, qui suit les correctifs de la 17). Le reste est du packaging tiers. Chart Helm `oci://code.forgejo.org/forgejo-helm/forgejo`, dont le numéro ne suit pas celui du logiciel |
| Mise à jour | Arrêter, sauvegarder, remplacer, redémarrer. Même structure de base tant que les deux premiers numéros sont identiques ; changer le deuxième migre la base, sans retour sauf par la sauvegarde | Sauvegarde complète exigée pour une nouvelle stable. On peut viser directement la dernière version, mais en lisant les notes intermédiaires. La base refuse un retour arrière. Versionnement sémantique depuis la 7.0.0 |
| Passage depuis Gitea | — | Documenté jusqu'à Gitea **1.22** incluse, en deux temps (Gitea 1.22 → Forgejo 10 → plus récent) |
| Sauvegarde | Instance arrêtée. `gitea dump` produit un zip (dépôts, `data/`, `app.ini`, un SQL) ; la remise en place est manuelle. Le SQL de l'outil a des problèmes ouverts pour MySQL et PostgreSQL. `SECRET_KEY` chiffre des valeurs, comme les secrets 2FA | Instance arrêtée. Avec SQLite et la configuration par défaut, copier `data` suffit (base, dépôts, fichiers, files, index), plus `app.ini`. `SECRET_KEY` déchiffre les identifiants de miroir et les secrets Actions ; `JWT_SECRET` signe les jetons OAuth |
| Push mirror vers GitHub | Écrase la copie distante ; le dépôt GitHub doit exister | Idem |

**Pour le homelab** : la forge est un pod sur `k3s-01`, une réplique, SQLite, avec ses données sur un zvol à part sous `tank/vmdata`. Le disque système (64 Go) et le zvol Vaultwarden ne les portent pas. Les deux images tiendraient dans le même pod et le même volume. Ce critère ne choisit pas.

Sources : [installation par binaire](https://docs.gitea.com/installation/install-from-binary/), [Docker](https://docs.gitea.com/installation/install-with-docker/), [Kubernetes](https://docs.gitea.com/installation/install-on-kubernetes), [mise à jour Gitea](https://docs.gitea.com/installation/upgrade-from-gitea), [sauvegarde Gitea](https://docs.gitea.com/administration/backup-and-restore), [configuration](https://docs.gitea.com/administration/config-cheat-sheet/), [miroirs Gitea](https://docs.gitea.com/usage/repository/repo-mirror/), [installation Forgejo](https://forgejo.org/docs/latest/admin/installation/), [Docker Forgejo](https://forgejo.org/docs/latest/admin/installation/docker/), [mise à jour Forgejo](https://forgejo.org/docs/latest/admin/upgrade/), [sauvegarde Forgejo](https://forgejo.org/docs/latest/admin/setup/backup/), [miroirs Forgejo](https://forgejo.org/docs/latest/user/repo-mirror/).

### 5. Écosystème

Aucun des deux ne documente de système de plugins. L'extension passe par l'API, les webhooks, les thèmes et des outils annexes. Le client qui pousse le code reste Git.

| | Gitea | Forgejo |
| --- | --- | --- |
| Documentation | Un seul jeu, toujours à jour, sur [docs.gitea.com](https://docs.gitea.com/) | Versionnée (`/docs/v17.0/`, `/docs/latest/`). Référence d'API générée sur l'instance (`/api/swagger`), compatible au sein d'une version majeure |
| Outils | Liste [awesome-gitea](https://gitea.com/gitea/awesome-gitea). Client en ligne de commande `gt` 1.0.0 (2 nov. 2026), qui remplace `tea` (archivé) et parle à Gitea 28 et plus | Liste [Delightful Forgejo](https://codeberg.org/forgejo-contrib/delightful-forgejo/). Numéro de version au format `X.Y.Z+gitea-A.B.C` : les outils prévus pour Gitea 1.22 et avant restent utilisables |
| Thèmes | `gitea-light`, `gitea-dark`, `gitea-auto` ; un thème en plus est un fichier `theme-<nom>.css` déclaré dans `THEMES` | Clair, sombre, auto, anciens thèmes Gitea, variantes pour daltonisme. Les modèles de pages personnalisés ne sont pas pris en charge et peuvent casser à une mise à jour |
| Communauté | [forum.gitea.com](https://forum.gitea.com/), actif (sujets du 2 nov. 2026) | Suivi du projet pour les bugs, salon Matrix, `security@forgejo.org` pour la sécurité. Instance publique : Codeberg |

**Pour le homelab** : le PC pousse avec Git, et le téléphone n'a pas besoin de client de forge. `gt` est un outil en plus côté Gitea, sans obligation de s'en servir. Ce critère ne choisit pas.

Sources : [intégrations Gitea](https://docs.gitea.com/development/integrations/), [personnalisation Gitea](https://docs.gitea.com/administration/customizing-gitea/), [annonce `gt` 1.0.0](https://blog.gitea.com/release-of-gitea-cli-1.0.0/), [API Forgejo](https://forgejo.org/docs/v17.0/user/api/usage/), [numérotation Forgejo](https://forgejo.org/docs/v17.0/user/api/versions/), [personnalisation Forgejo](https://forgejo.org/docs/latest/admin/advanced/customization/), [configuration Forgejo](https://forgejo.org/docs/v17.0/admin/config-cheat-sheet/), [discussions Forgejo](https://forgejo.org/docs/latest/contributor/discussions/).

### 6. Coût opérationnel

Les deux s'installent sans abonnement. Le vrai coût est la mémoire de `k3s-01`, le disque des dépôts et le temps passé en mises à jour.

| | Gitea | Forgejo |
| --- | --- | --- |
| Ressources minimales | Un Raspberry Pi 3 pour une petite charge ; 2 cœurs et 1 Go de RAM pour une petite équipe. Git 2.0 ou plus | Pas de minimum publié |
| SQLite | Livré avec le binaire, mais déconseillé sous charge ; mieux vaut choisir la base définitive à l'installation | Recommandé pour une activité faible ou moyenne : un à trois fichiers, sans entretien sauf un `VACUUM` occasionnel |
| Édition payante | Enterprise : 9,50 $ par utilisateur et par mois, engagement d'un an (19 $ barré), avec SAML, liste d'adresses IP, support garanti | Aucune |
| Rythme des versions | Fréquent (18 oct., puis 1er nov. 2026) | Une stable tous les trois mois ; une LTS par an, suivie quinze mois (la 15.0 jusqu'au 15 juil. 2027) |

**Pour le homelab** : une personne, quelques dépôts, SQLite, pas de second pod pour une base. Constat du 3 nov. dans la VM `k3s-01` : 8 Gio attribués, 7,5 Gio vus, 5,5 Gio disponibles, 4 cœurs, échange inutilisé, 51 Go libres sur le disque système. La marge est suffisante. Forgejo demanderait moins de mises à jour en restant sur une LTS. Ce critère ne choisit pas.

Sources : [présentation Gitea](https://docs.gitea.com/), [préparation de la base Gitea](https://docs.gitea.com/installation/database-prep/), [tarifs Gitea](https://about.gitea.com/pricing/), [recommandations Forgejo](https://forgejo.org/docs/latest/admin/setup/recommendations/), [base Forgejo](https://forgejo.org/docs/latest/admin/installation/database-preparation/).
