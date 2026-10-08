# Observabilité StreamBox

Ce module configure Cloud Monitoring, les alertes email et l'archivage des logs. La configuration locale de [Prometheus et Grafana](../../../monitoring/README.md) complète les outils GCP.

## Configuration du groupe

| Paramètre | Valeur |
| --- | --- |
| Projet | `streambox-insset-m1-2026` |
| Région | `europe-west9` |
| Service Cloud Run | `streambox-catalogue` |
| URL map | `streambox-url-map` |
| Email | `swann.defossezanceaux@gmail.com` |
| Bucket d'archives | `bucket-insset-streambox-logs`, COLDLINE |

Le [module racine](../../main.tf) transmet ces valeurs. Cloud Run et le Load Balancer sont réalisés par les autres membres du groupe. Les noms doivent correspondre aux ressources déployées ; sans trafic, les graphiques peuvent rester vides.

## Ressources et fichiers

| Fichier | Contenu |
| --- | --- |
| `main.tf` | Canal email et dashboard Cloud Monitoring de 11 graphiques |
| `alerts.tf` | Politiques d'erreurs 5xx et de latence p95 |
| `filters.tf` | Filtres communs et API Monitoring/Logging |
| `archive.tf` | Sink et droit d'écriture dans le bucket existant |
| `prometheus.tf` | Compte de lecture Monitoring et API IAM/IAM Credentials |
| `outputs.tf` | Liens, identifiants, filtre de logs et identités |

Tous les fichiers Terraform du dossier composent un seul module. Aucun compte de service ne reçoit de clé JSON. La suppression du module ne désactive pas les API activées.

## Dashboard

Les 11 graphiques couvrent :

- Catalogue : requêtes/s, p95 en millisecondes, erreurs 5xx/s, proportion de 5xx.
- Cloud Run : nombre moyen d'instances actives et inactives.
- Médias : requêtes par résultat du cache, proportion de HIT complets, octets distribués par minute, requêtes à l'origine, octets reçus de l'origine par minute.
- Load Balancer : erreurs 5xx sur toutes les routes de l'URL map.

Les métriques du catalogue agrègent les routes et révisions du service. Le p95 représente le traitement dans Cloud Run, hors démarrage et trajet navigateur. Les données peuvent apparaître plusieurs minutes après l'essai ; une série absente ne signifie pas zéro. [Métriques Cloud Run](https://docs.cloud.google.com/monitoring/api/metrics_gcp_p_z).

Les graphiques média filtrent `BACKEND_BUCKET` : ils supposent que les backend buckets de cette URL map servent les médias du projet. Les métriques backend incluent des HIT synthétiques, donc le filtre origine conserve seulement MISS et DISABLED, et exclut UNKNOWN. Recouper avec les logs, notamment pour les requêtes Range. Le volume réseau n'est pas une facture. [Métriques Load Balancing](https://docs.cloud.google.com/monitoring/api/metrics_gcp_i_o).

## Alertes

Ces seuils sont des **valeurs de départ**, à ajuster avec la référence du labo ; ils ne sont pas des exigences validées par le professeur.

| Politique | Déclenchement |
| --- | --- |
| Erreurs | Plus de 1 % de 5xx et au moins 100 requêtes sur 5 minutes, conditions maintenues 60 secondes |
| Latence | p95 supérieur à 1 000 ms, mesuré par fenêtres de 60 secondes, pendant 5 minutes |

Les deux politiques notifient l'ouverture et la fermeture. Les données manquantes sont traitées comme une condition inactive ; une fermeture automatique après 30 minutes sans données est configurée. Une fermeture seule ne prouve donc pas la guérison : vérifier aussi une requête réussie et des métriques revenues à la normale.

Sur un essai peu chargé, le minimum de 100 requêtes peut empêcher volontairement l'alerte erreurs. Adapter ce paramètre pour une démonstration contrôlée, puis restaurer sa valeur.

## Logs et archives

Les journaux restent dans **Cloud Logging / Logs Explorer** pour déboguer. Le sink copie les nouveaux logs du service Cloud Run et de l'URL map vers GCS. Il ne déplace pas les logs et ne modifie pas la rétention Cloud Logging existante.

Son identité reçoit uniquement `roles/storage.objectCreator` sur le bucket d'archives. Le compte Prometheus n'a pas accès aux archives. Le bucket existe déjà et reste géré par le responsable des buckets : le module observability réutilise son nom et ajoute seulement le droit d'écriture du sink.

Le contrôle GCP du 8 octobre 2026 a confirmé la classe COLDLINE, la région europe-west9 et l'absence de droits publics dans les politiques IAM consultées. La prévention d'accès public est `inherited` et aucune suppression automatique à 90 jours n'est configurée. Nous conservons ces réglages : les changements de protection ou de rétention sont à coordonner avec le responsable du bucket. Coldline a une durée minimale de stockage facturée de 90 jours, ce qui ne constitue pas une règle de suppression automatique. [Classes de stockage](https://docs.cloud.google.com/storage/docs/storage-classes).

L'export peut prendre plusieurs heures au démarrage et ne reprend pas automatiquement les anciens logs. Vérifier que le Load Balancer émet réellement ses journaux et qu'ils ne sont pas exclus en amont. [Export vers Cloud Storage](https://docs.cloud.google.com/logging/docs/export/storage).

## Variables

| Variable | Type | Défaut |
| --- | --- | --- |
| `project_id`, `region` | string | Obligatoires |
| `cloud_run_service_name`, `load_balancer_url_map_name` | string | Obligatoires |
| `notification_email` | string | Obligatoire, format vérifié |
| `alerts_enabled` | bool | `true` |
| `error_ratio_threshold` | number | `0.01`, strictement entre 0 et 1 |
| `minimum_requests` | number | `100`, entier positif |
| `latency_p95_threshold_ms` | number | `1000`, positif |
| `enable_log_archive` | bool | `false` ; activé à la racine |
| `log_archive_bucket_name` | string | Vide ; requis si archivage actif |
| `create_prometheus_reader` | bool | `false` ; activé à la racine |

La sortie racine `observability` regroupe le lien du dashboard, les identifiants des politiques et du canal, le filtre Logs Explorer, le nom du bucket et les identités du sink et de Prometheus.

## Vérification locale

Depuis la racine du dépôt :

```powershell
terraform -chdir=terraform init -backend=false -lockfile=readonly
terraform fmt -check -recursive terraform
terraform -chdir=terraform validate
terraform -chdir=terraform test
```

Les [quatre tests](../../tests/observability.tftest.hcl) utilisent un provider simulé, sans déploiement : filtres et alertes, archivage et permissions, bucket manquant et valeurs invalides. Ils ne prouvent ni l'acceptation des filtres par GCP ni la réception des emails.

## Intégration et mise en service

1. Intégrer les modules du groupe et coordonner le **state distant** avant un apply partagé. Son bucket est distinct du bucket de logs.
2. Vérifier les droits du compte de déploiement. Si une ressource existe hors du state, coordonner son import ou sa réutilisation avec son responsable.
3. Initialiser avec le backend du groupe, puis relire le plan complet. La racine gère aussi les buckets ; ne pas utiliser `-target` comme méthode normale de déploiement.
4. Appliquer le plan validé avec le groupe, puis consulter `terraform -chdir=terraform output observability`.
5. Ouvrir le dashboard, vérifier le canal email dans Monitoring et effectuer sa vérification si demandée. Prouver ensuite la réception réelle des notifications.
6. Lancer Prometheus/Grafana selon leur README et vérifier le sink après le délai d'export.

L'initialisation locale avec `-backend=false` ne configure pas le state partagé.

### Intégration du 8 octobre 2026

La branche `dev` a été intégrée avec les modules `media` et `catalogue`. Le plan complet retrouve correctement les buckets et le CDN, mais propose de créer le catalogue alors que le service et son compte existent déjà dans GCP. Le responsable du catalogue doit coordonner leur import ou la migration de leur state vers le backend commun, y compris le droit `run.invoker` géré par son module.

Pour ce premier déploiement, un plan ciblant `module.observability` est utilisé exceptionnellement afin de laisser les ressources du catalogue intactes. Les dépendances de ce plan sont également relues : il ne doit créer ou modifier aucun bucket. Ne pas généraliser ce ciblage aux déploiements suivants ; refaire un plan complet après réconciliation du state du catalogue.

## Diagnostic et preuves

**Périmètre du labo :** média de moins de 1 Mo ; référence à 1 utilisateur pendant 2 minutes ; progression 1, 5 puis 10 utilisateurs sur 5 minutes au total maximum. Les 2 000 vidéos d'environ 1 Go servent uniquement à l'estimation annuelle théorique.

Pour chaque essai, conserver début/fin, nombre de requêtes, p95, 5xx, HIT/MISS, accès à l'origine et volumes. Séparer catalogue et médias, en passant par le Load Balancer.

En cas d'incident catalogue :

1. Comparer les logs, la révision, le trafic, le p95 et les instances sur la même période.
2. Vérifier mémoire, concurrence et limites d'instances avec le responsable Cloud Run. Arrêter un essai si sa règle d'arrêt est atteinte.
3. Si une révision est en cause, coordonner le retour à une révision connue.
4. Vérifier une requête réussie, les métriques et la fermeture de l'incident ; conserver les emails.

Une 404 n'est pas une 5xx. Pour tester les alertes, préparer avec le responsable du catalogue un scénario temporaire, réversible et borné d'erreur serveur ou de latence sur le labo. Tenir compte des fenêtres et du délai des métriques. Si des seuils sont abaissés pour la démonstration, consigner ces valeurs puis les restaurer. Aucun endpoint de panne n'est ajouté au kit.

En cas de MISS persistants, vérifier URL, Cache-Control, configuration CDN et requêtes Range. Pour une archive vide, vérifier les entrées dans Logs Explorer, le filtre, l'identité du sink, ses droits et le délai d'export.

Pour le rendu, conserver les captures du dashboard, des incidents, des emails effectivement reçus, d'une entrée de log et d'un objet d'archive. Une validation Terraform ne remplace pas ces preuves.
