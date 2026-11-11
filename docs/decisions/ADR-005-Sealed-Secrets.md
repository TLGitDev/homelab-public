# ADR-005 — Secrets Kubernetes : Sealed Secrets

## Statut

Accepté. Remplace SOPS + age, utilisé jusqu'au sprint 17.

## Contexte

Les applications déployées en GitOps par Argo CD ont besoin de Secrets Kubernetes. Or un Secret n'est **pas chiffré** par défaut : il est seulement encodé en Base64, y compris au repos dans etcd. Le dépôt Git ne doit contenir aucune valeur en clair.

Le besoin est modeste : un petit homelab, peu de secrets, et **pas** de gestionnaire de secrets externe (Vault, AWS Secrets Manager, 1Password…).

## Décision

Utiliser **Sealed Secrets** pour les Secrets Kubernetes gérés en GitOps.

```
Git
 │
 └── SealedSecret (chiffré)
          │
          ▼
   Controller Sealed Secrets
          │
          ▼
     Secret Kubernetes
          │
          ▼
      Application
```

Le secret fait partie de l'état versionné, sans que sa valeur en clair soit dans Git. Argo CD applique des manifestes Kubernetes ordinaires, sans étape `sops --decrypt | kubectl apply`.

Un SealedSecret est chiffré pour **un cluster, un namespace et un nom** précis : changer l'un des trois oblige à le rechiffrer (*reseal*).

## Raisons

- Une représentation chiffrée qu'on peut versionner, et qu'Argo CD consomme directement.
- Le déchiffrement a lieu **dans** le cluster, par le controller, jamais sur le poste ni dans une CI.

## Alternatives étudiées

| Option | Commentaire |
| --- | --- |
| SOPS + age | Utilisé jusqu'au sprint 17. Ce n'est pas un mauvais outil, mais il imposait un déchiffrement **à l'extérieur** du contrôleur GitOps |
| External Secrets | Répond à un autre besoin : faire consommer à Kubernetes un gestionnaire de secrets externe, qui n'existe pas ici. Sealed Secrets n'est pas « meilleur », le périmètre est différent |
| Secret en clair dans Git | Inacceptable, même dans un dépôt privé, et encore plus en vue d'un portfolio public |

## Conséquences

- Git contient des SealedSecrets, jamais le token d'administration, son hash PHC, ni le texte chiffré recopié dans la doc.
- Pour Vaultwarden, le Secret contient le hash Argon2id (`$argon2id$…`), pas le token qu'on tape sur `/admin` (voir [vaultwarden.md](../exploitation/vaultwarden.md)).
- Une variable d'environnement issue d'un Secret n'est pas rechargée toute seule : après un *reseal*, il faut un `rollout restart`.
- Le Secret créé dans le cluster reste lisible par l'API (`kubectl get secret`) : ce n'est pas un coffre-fort interne.
- SOPS peut rester visible dans l'historique Git, mais ce n'est plus le mécanisme en service.
- **La clé du controller est critique** et vit hors de Git : sur `k3s-01` dans `~/backups/sealed-secrets/` (mode `600`), avec une copie manuelle dans `/tank/backups/k3s-01/sealed-secrets/`, puis sur le disque USB par `backup-usb`. Sans elle, un cluster neuf ne peut pas déchiffrer les SealedSecrets existants (voir [restauration.md](../exploitation/restauration.md), scénario 5).
