# Sauvegardes

> RAID, snapshots et sauvegardes : trois protections différentes.
>
> Principes d'architecture : [Architecture.md](Architecture.md). Stockage ZFS : [Stockage.md](Stockage.md).

---

# Définition

Une sauvegarde est une copie **indépendante** permettant de restaurer le système après une perte ou une corruption.

Elle ne doit pas être confondue avec le RAID ou les snapshots.

---

# Objectifs

Adaptés à un usage personnel, pour garder l'infrastructure simple :

| Indicateur | Objectif |
|------------|----------|
| RTO (Recovery Time Objective) | 1 journée maximum |
| RPO (Recovery Point Objective) | 24 heures maximum |

RTO : durée maximale pour remettre le service en état.

RPO : quantité maximale de données que l'on accepte de perdre.

---

# Trois protections distinctes

## RAID / miroir ZFS

Protège contre la panne d'un disque.

Ne protège pas contre :

- une suppression accidentelle ;
- un ransomware ;
- une corruption logique ;
- une erreur humaine.

Toute modification est immédiatement répliquée sur les deux disques.

Le RAID améliore la **disponibilité**, pas la sauvegarde.

Aujourd'hui : `rpool` n'a pas de miroir (un seul NVMe). `tank` est un miroir de deux HDD. Le miroir de `tank` n'est pas une sauvegarde.

## Snapshots

Permettent de revenir rapidement à un état précédent.

Adaptés pour : tester une mise à jour, modifier une configuration importante, revenir en arrière après une erreur.

Ils sont stockés sur le **même** pool ZFS. Ils ne protègent pas contre une perte totale du stockage.

## Sauvegardes

Stockées sur un support indépendant.

Elles permettent de reconstruire complètement une machine après une panne matérielle.

C'est le dernier niveau de protection.

---

# Stratégie retenue

```
Couche 1    ZFS (checksums ; miroir IronWolf sur `tank`)
                ↓
            Protège contre la corruption silencieuse
            et contre la panne d'un HDD de données.

Couche 2    Snapshots ZFS
                ↓
            Protègent contre les erreurs récentes.

Couche 3    Sauvegardes Proxmox
                ↓
            Disque USB externe dédié
                ↓
            Restauration complète du serveur.

Couche 4    Sauvegarde hors site (future)
                ↓
            Copie chiffrée sur un support dans un autre lieu.
```

État : stratégie écrite, **pas encore mise en œuvre**. Tests de restauration : à faire.

---

# Principes

## Indépendance

Une sauvegarde doit être stockée sur un support distinct de celui qui contient les données d'origine.

## Versionnement

Plusieurs générations doivent être conservées, pour revenir en arrière si une corruption ou une erreur est découverte tardivement.

## Automatisation

Une sauvegarde automatique imparfaite est préférable à une sauvegarde manuelle parfaite qui n'est jamais exécutée.

## Validation

Une sauvegarde n'existe réellement que lorsqu'une restauration a été réalisée avec succès. Créer une copie n'est pas suffisant. Il faut vérifier régulièrement qu'elle restaure vraiment les données.
