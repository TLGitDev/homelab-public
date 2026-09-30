# ADR-005 — Secrets Kubernetes (Sealed Secrets)

## Statut

Accepté

## Contexte

Les applications GitOps (Argo CD) ont besoin de Secrets Kubernetes. Un Secret n'est pas chiffré au repos dans etcd par défaut (Base64). Le dépôt Git ne doit pas contenir les valeurs en clair.

Le besoin actuel : petit homelab, peu de secrets, **pas** de gestionnaire externe (Vault, AWS Secrets Manager, 1Password…).

## Décision

Utiliser **Sealed Secrets** pour les Secrets Kubernetes **gérés par GitOps**.

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

Le secret fait partie de l'état GitOps sans que sa valeur en clair soit dans Git. Argo CD applique des manifestes Kubernetes, sans étape `sops --decrypt | kubectl apply`.

Exemple : [Vaultwarden.md](../Vaultwarden.md#sealed-secrets). GitOps : [ArgoCD.md](../ArgoCD.md).

Un SealedSecret est lié au cluster, au namespace et au nom : un changement impose de **resealer**.

## Raisons

- Représentation chiffrée versionnable, consommable directement par Argo CD.
- Le déchiffrement a lieu **dans** le cluster (controller), pas sur le poste ni dans une CI.

## Alternatives étudiées

| Option | Commentaire |
|--------|-------------|
| SOPS + age | Utilisé historiquement (sprint 17). Pas « mauvais ». N'est plus le mécanisme des Secrets Kubernetes déployés par Argo CD : il imposait un déchiffrement **externe** au contrôleur GitOps. |
| External Secrets | Répond à un autre besoin : Kubernetes **consomme** un secret manager externe. Ce besoin n'existe pas aujourd'hui. Sealed Secrets n'est pas « meilleur » ; le périmètre est différent. |
| Secret en clair dans Git | Inacceptable, même en dépôt privé, surtout en vue d'un portfolio public. |

## Conséquences

- Git contient des SealedSecrets, jamais `ADMIN_TOKEN` (ni équivalent) en clair.
- Le Secret créé dans le cluster reste lisible via l'API (`kubectl get secret`) : ce n'est pas un coffre-fort interne.
- SOPS peut rester visible dans l'historique Git ; ce n'est plus le flux opérationnel.
