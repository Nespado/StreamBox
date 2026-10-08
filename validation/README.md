# Validation StreamBox — 8 octobre 2026

Projet : `streambox-insset-m1-2026`, région `europe-west9`. Cible du labo : https://streambox.chaleonm.ovh. Les horodatages JSON sont en UTC ; ajouter deux heures pour Paris ce jour-là.

## Charge nominale et CDN

Essai de 14:24:55 à 14:28:55 UTC : 1 utilisateur pendant 120 s, puis 5 pendant 60 s, puis 10 pendant 60 s. Chaque utilisateur demande le catalogue puis une vidéo toutes les 5 s. Ce protocole mesure une petite charge régulière, pas la capacité maximale du service.

La vidéo fait **39 631 octets** (moins de 1 Mo). Les **408 requêtes ont toutes répondu 200**, sans règle d'arrêt déclenchée ; 8 184 276 octets de corps de réponse ont été téléchargés. Les 204 lectures vidéo ont toutes retourné `X-Cache-Status: hit` : le cache était déjà chaud.

| Utilisateurs | Durée | Requêtes API / média | p95 API côté client | p95 média côté client |
| --- | --- | --- | --- | --- |
| 1 | 120 s | 24 / 24 | 206,19 ms | 193,46 ms |
| 5 | 60 s | 60 / 60 | 659,75 ms | 188,77 ms |
| 10 | 60 s | 120 / 120 | 653,44 ms | 197,61 ms |

Le p95 client inclut le réseau, TLS et la lecture du corps. Le p95 estimé par l'histogramme Cloud Run est de 9,5 ms sur les points observés ; une instance est observée. Les séries GCP du service et du Load Balancer peuvent aussi inclure le trafic des autres membres du groupe. Ne pas attribuer tous leurs octets à cet essai. Une série absente (notamment erreurs ou origine) n'est pas une mesure de zéro.

Preuves : [protocole](results/20261008T142455Z/protocol.json), [requêtes](results/20261008T142455Z/requests.json), [résumé](results/20261008T142455Z/summary.json), [11 requêtes du dashboard et réponses GCP](results/20261008T142455Z/dashboard-metrics.json). Dans cette capture, les expressions contenant `$__range` sont évaluées avec une fenêtre glissante de 5 minutes, pas une intégrale exacte de l'essai.

### Deux politiques de cache

Une copie temporaire du même média a servi à comparer les politiques. L'objet original et les paramètres du bucket n'ont pas été modifiés.

| Cache-Control | Trois lectures successives | Temps client |
| --- | --- | --- |
| `public,max-age=60` | MISS, HIT, HIT | 210,24 / 149,22 / 175,52 ms |
| `no-store` | MISS, MISS, MISS | 207,58 / 246,27 / 197,36 ms |

Les HIT évitent de relire l'origine pour ces réponses ; les MISS de cet objet existant nécessitent de solliciter l'origine. Cette petite comparaison illustre le fonctionnement du cache, sans établir un gain de performance statistique. Les six réponses sont des 200 de 39 631 octets. L'objet temporaire a été supprimé et son chemin invalidé dans le CDN.

[Preuve de la comparaison et du nettoyage](results/20261008T143742Z-cache/evidence.json).

Un [premier essai](results/20261008T143353Z-cache/evidence.json) a conservé l'ancienne réponse en cache après changement de métadonnées : ajouter un paramètre à l'URL ne suffisait pas à changer la clé de cache dans cette configuration. Il ne prouve pas le fonctionnement de `no-store`. L'essai final invalide explicitement le seul chemin temporaire entre les deux politiques, puis vérifie le nouvel en-tête avant mesure.

## Alertes et rétablissement

Un service Cloud Run **privé et temporaire**, limité à une instance, a reçu 120 réponses 500 retardées de 1 500 ms, puis 36 réponses 200. Une requête initiale 200 a vérifié son accès. Le catalogue public n'a pas reçu de panne artificielle.

Deux copies des politiques existantes utilisaient le canal email du groupe. Le seuil 5xx est resté identique (>1 %, au moins 100 requêtes sur 5 minutes, maintien 60 s). Le maintien de la latence a été réduit de **300 à 60 secondes uniquement sur la copie de test**, seuil 1 000 ms inchangé. Le libellé de condition retourné dans la preuve historique conserve « 5 minutes » : la durée effective est le champ `duration: 60s`. Cela valide la chaîne technique avec ce maintien réduit, pas une panne de cinq minutes sur le catalogue réel.

| Politique de test | Ouverture UTC | Fermeture UTC |
| --- | --- | --- |
| Latence | 14:37:51 | 14:40:30 |
| 5xx | 14:39:38 | 14:43:14 |

L'API Monitoring retourne deux incidents pour les deux conditions de la politique 5xx ; tous deux sont fermés. Les métriques confirment le rétablissement avant fermeture : p95 d'environ 1 555 ms revenu à 9,5 ms, proportion de 5xx revenue à zéro pendant les réponses saines. Les points `NaN` après arrêt du trafic ne sont pas interprétés comme zéro.

**Swann a confirmé dans la conversation avoir reçu les emails des deux alertes.** La réception des emails de fermeture n'a pas été confirmée séparément. Conserver les emails pour le rendu ; aucun accès à la boîte mail n'a été réalisé.

Le service et les deux politiques temporaires ont été supprimés après fermeture des incidents ; les politiques du catalogue restent inchangées. [Requêtes, incidents, configuration des copies et nettoyage](results/20261008T143221Z-alerts/evidence.json), [métriques de rétablissement](results/20261008T143221Z-alerts/recovery-metrics.json). Seuls les panneaux catalogue de cette dernière capture concernent le service temporaire ; les panneaux média restent ceux de l'URL map commune.

## Logs et archives

Cloud Logging contient les requêtes du Load Balancer. Le bucket existant `bucket-insset-streambox-logs` est en COLDLINE, dans `europe-west9`. Au contrôle de 14:36 UTC, il contenait **12 objets et 4 304 720 octets**. Une archive de requêtes a été ouverte et contenait **640 entrées du service `streambox-catalogue`**.

Le filtre du sink utilisait à tort `https_lb_rule` pour les logs du Load Balancer. La correction utilise `http_load_balancer` pour les logs et conserve `https_lb_rule` pour les métriques. Le plan appliqué a modifié **uniquement le sink**, sans créer ni modifier de bucket. Un test Terraform couvre cette distinction.

[Preuves des logs et de l'archive](results/20261008T142455Z/logging-archive-proof.json). **L'export effectif des logs du Load Balancer après correction reste à vérifier** : aucun objet de ce type n'était présent au contrôle. Le sink exporte par lots et ne reprend pas automatiquement les anciens logs. Ne pas présenter cette partie comme déjà prouvée. Coldline ne supprime pas automatiquement les objets à 90 jours.

## Rejouer les essais

Depuis la racine du dépôt, avec Python 3 et un compte `gcloud` autorisé sur le projet :

```powershell
python validation/load.py
python validation/cache.py
python validation/alerts.py
```

Ne pas les lancer automatiquement à chaque commit : `load.py` génère du trafic réel ; `cache.py` crée puis supprime une petite copie dans le bucket média et invalide seulement son chemin ; `alerts.py` crée un service privé et deux politiques temporaires, et **envoie des notifications via Monitoring**. Aucun token n'est écrit dans les preuves. Le compte exécutant les deux derniers scripts doit avoir les droits nécessaires pour leurs créations et nettoyages. Ne pas fermer brutalement le processus ; contrôler les champs `cleanup` et les ressources après toute interruption.

`load.py` limite l'essai à 240 s, 450 requêtes et un seuil de 10 Mio de corps reçus (des requêtes déjà en cours peuvent terminer). Il s'arrête sur trois échecs consécutifs ou plus de 5 % d'échecs après 20 requêtes. Il vérifie la taille du média avant de démarrer. `alerts.py` borne le trafic à 120 s de panne et 180 s de réponses saines, puis attend au plus 600 s la fermeture avant nettoyage. Les JSON indiquent le résultat réel, y compris un éventuel incident encore ouvert à l'expiration du délai.

Pour conserver les métriques en lecture seule sur un autre intervalle :

```powershell
python validation/snapshot.py --start 2026-10-08T14:24:00Z --end 2026-10-08T14:30:00Z --out validation/results/nouveau-controle.json
```

Les scripts sont adaptés au projet du groupe et conservent chaque nouvel essai dans un dossier daté. Les preuves JSON sont complémentaires aux captures Grafana, aux incidents dans la console et aux emails à joindre au rendu. La CI reste une étape distincte à réaliser à la fin.

## Contrôle final

À 14:47 UTC, l'API catalogue, le média et la page de connexion Grafana répondent 200. Les cinq ressources temporaires (un service, deux politiques, deux objets) sont absentes, vérifiées par des réponses API 404. [Contrôle final](results/final-check.json). Aucune archive du Load Balancer n'est encore visible à cet instant.

`terraform fmt -check -recursive terraform`, `terraform validate` et les **8 tests Terraform** réussissent. Le plan complet après nettoyage retourne **No changes**, code 0. Les quatre scripts Python passent le contrôle de syntaxe et `git diff --check` ne signale aucune erreur. Les modifications et les preuves restent locales sur la branche `streambox-grafana`, sans commit ni push effectué pendant ces essais.
