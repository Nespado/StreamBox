# Image Grafana pour Cloud Run

Cette image reprend Grafana OSS officiel et embarque la source Prometheus ainsi
que le dashboard StreamBox. La version `13.2.3` et son digest sont fixés dans le
Dockerfile. Aucun mot de passe, jeton Google ou fichier ADC n'est embarqué.

## État actuel

L'image est construite, testée et publiée dans Artifact Registry sous
`europe-west9-docker.pkg.dev/streambox-insset-m1-2026/streambox/grafana:13.2.3-1`,
digest `sha256:9d1fd4241d432e858c0ad8523287c3fbef9f1537117e6e6ee028e0b4ff9eaaac`.
Le [module Terraform Grafana](../../terraform/modules/grafana/README.md) configure
le service, les secrets, l'identité et le proxy. Le module `delivery` configure
la route du Load Balancer. Le plan est vérifié ; l'application sur GCP reste à faire.

Le dashboard utilise les noms de métriques natifs GCP en PromQL. Les 11 requêtes
ont été acceptées par l'API du projet le 8 octobre 2026. Certaines ont retourné
des données ; les séries absentes ne sont pas une preuve de trafic nul ni
d'absence d'erreur. Ce contrôle utilise l'identité gcloud du développeur et ne
valide pas encore les permissions du futur service Cloud Run.

## Circuit de lecture prévu

```text
Navigateur → Load Balancer /monitoring/ → Grafana sur Cloud Run
Grafana → proxy d'authentification interne → API Google Managed Service for Prometheus
                                           → métriques natives Cloud Monitoring
```

La source Grafana de type `prometheus` attend `PROMETHEUS_URL`, l'adresse du proxy
qui ajoute et renouvelle les jetons Google grâce à l'identité attachée au service.
Le proxy n'est pas inclus dans cette image. Terraform le configure comme second
conteneur du même service Cloud Run, sans exposer son port au Load Balancer.
Dans ce cas, `http://127.0.0.1:9090` désignera
le proxy dans Cloud Run, **pas le PC d'un membre du groupe**.

Google documente le [frontend servant de proxy d'authentification](https://docs.cloud.google.com/stackdriver/docs/managed-prometheus/query-api-ui).
Ce composant ne stocke pas les métriques. Aucun serveur Prometheus avec disque
local ni exporter Stackdriver n'est nécessaire pour lire les métriques natives
déjà collectées par GCP. L'URL HTTPS de l'API Google seule ne suffit pas : la
source Prometheus Grafana doit aussi recevoir une authentification renouvelable.
Ne pas injecter un jeton manuel à durée limitée dans l'image.

Les métriques applicatives personnalisées au format Prometheus nécessiteraient
une instrumentation et une collecte supplémentaires ; cette image n'en ajoute pas.

## Construire et vérifier

Depuis la racine du dépôt, avec Docker démarré en mode conteneurs Linux :

```powershell
docker build --platform linux/amd64 -t streambox-grafana:13.2.3-1 monitoring/grafana-cloudrun
python monitoring/grafana-cloudrun/tests/smoke.py
```

Le test lance puis supprime deux conteneurs temporaires, sans volume partagé ni
identifiants Google. Il vérifie le refus de démarrer sans mot de passe, le port
8080, le chemin `/monitoring/`, le refus d'accès anonyme au dashboard, la source
provisionnée et les 11 panneaux recréés sur chaque instance neuve. Il ne vérifie
pas la connexion Grafana → GCP. Aucun hébergement local permanent n'est créé.

Le contexte de build est limité à ce dossier et filtré par une liste autorisée
dans `.dockerignore`. Les fichiers `.env` et les tests ne sont pas copiés.

## Paramètres à fournir au déploiement

| Paramètre | Valeur ou rôle |
| --- | --- |
| `PORT` | Fourni par Cloud Run ; 8080 par défaut pour le test. |
| `GF_SERVER_ROOT_URL` | URL publique complète, par exemple `https://streambox.chaleonm.ovh/monitoring/` une fois HTTPS opérationnel. |
| `PROMETHEUS_URL` | URL du proxy interne authentifié vers l'API Prometheus de Google. |
| `GF_SECURITY_ADMIN_USER` | Identifiant initial ; `admin` par défaut. |
| `GF_SECURITY_ADMIN_PASSWORD` | Mot de passe initial injecté depuis Secret Manager. Obligatoire, sauf usage de la variante fichier ci-dessous. |
| `GF_SECURITY_ADMIN_PASSWORD__FILE` | Variante : chemin du secret monté en fichier. Ne pas fournir les deux variantes. |
| `GF_SECURITY_COOKIE_SECURE` | À régler sur `true` pour l'accès public HTTPS. |
| `GF_SECURITY_SECRET_KEY` | Secret stable à injecter depuis Secret Manager pour la configuration déployée. |

Grafana écoute en HTTP dans le conteneur ; le Load Balancer termine HTTPS. La
route doit conserver `/monitoring/` et couvrir `/monitoring` et `/monitoring/*`.
Le contrôle de santé peut utiliser `/monitoring/api/health` : il valide le serveur
et sa base, pas l'accès aux métriques Google.

Le dashboard permet de sélectionner projet, région, service et URL map. Les
valeurs initiales sont celles du labo : `streambox-insset-m1-2026`, `europe-west9`,
`streambox-catalogue` et `streambox-url-map`. Changer le champ projet ne donne
aucune permission supplémentaire et ne change pas le projet de requête du proxy.

## Conservation et mises à jour

Les panneaux et la source sont provisionnés à chaque démarrage depuis l'image.
Modifier les fichiers du dépôt, reconstruire l'image avec une nouvelle version,
puis déployer son digest. Les modifications des dashboards via l'interface sont
désactivées pour garder Git comme référence.

La base SQLite reste éphémère sur Cloud Run : utilisateurs supplémentaires,
sessions et préférences peuvent disparaître au remplacement d'une instance.
Cette image ne constitue pas un Grafana avec état utilisateur durable. Pour le
labo, prévoir au plus une instance en régime normal ; un remplacement ou un
déploiement peut quand même imposer une reconnexion. Une utilisation durable ou
multi-instance nécessite une base externe prise en charge par Grafana.

Les métriques restent chez Google. Les alertes email restent dans Cloud Monitoring
et les archives de logs dans le bucket GCS ; le moteur d'alertes Grafana est désactivé.

L'ancienne stack [Compose locale](../README.md) utilise un autre dashboard, avec
les noms de métriques de l'exporter. Elle n'est pas utilisée par cette image.

Référence : [PromQL et noms de métriques GCP](https://docs.cloud.google.com/monitoring/promql).
