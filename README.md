# StreamBox, kit de démarrage

Une petite API catalogue avec son interface, prête à tourner sur Cloud Run, et de quoi tout faire fonctionner sur votre machine avant de toucher à GCP. Le kit est un démonstrateur : il sert à vérifier votre infrastructure, il n’est pas évalué.

## Ce qu’il contient

```text
catalogue/            Le code à déployer sur Cloud Run
  server.mjs          API (/api/catalogue) et page d’accueil, sans dépendance
  catalogue.json      Les trois vidéos de démonstration
  public/             Interface : lecteur, chemin de l’API, chemin des médias
  Dockerfile
local/                Ce qui remplace GCP en local, jamais déployé
  edge.conf           nginx dans le rôle du Load Balancer, de Cloud CDN et du bucket
  medias.sh           Fabrique les vidéos de test avec ffmpeg
docker-compose.yml
```

## Observabilité du projet

La configuration des dashboards, alertes email et archives est décrite dans le [module Terraform observability](terraform/modules/observability/README.md). L'[image Grafana pour Cloud Run](monitoring/grafana-cloudrun/README.md) embarque les dashboards et la configuration pour l'hébergement GCP. Le [module Terraform Grafana](terraform/modules/grafana/README.md) déploie le service, ses secrets et le proxy vers les métriques. Grafana est déployé et vérifié à l'adresse [StreamBox Monitoring](https://streambox.chaleonm.ovh/monitoring/) ; la procédure de connexion est dans le README du module. L'ancienne stack locale est documentée dans le [guide monitoring](monitoring/README.md).

## Lancer en local

Il faut Docker avec Compose. Le premier lancement télécharge les images et fabrique les vidéos, ce qui prend une minute.

```sh
docker compose up --build
```

Ouvrez ensuite http://localhost:8080. Cliquez sur « Télécharger la vidéo » plusieurs fois : le premier essai est un `MISS`, les suivants des `HIT`, et le temps chute. Les vidéos sont rangées dans `bucket/media/`, exactement comme les objets du futur bucket.

| Rôle | En local | Sur GCP |
| --- | --- | --- |
| Point d’entrée et routage | nginx, `local/edge.conf` | Application Load Balancer et URL map |
| Cache | cache nginx et en-tête `X-Cache-Status` | Cloud CDN sur le backend bucket |
| Stockage des vidéos | dossier `bucket/media` | Bucket Cloud Storage, objets `media/...` |
| API et interface | conteneur `catalogue` | Cloud Run, derrière un serverless NEG |

Le cache local n’est qu’une imitation : il montre le principe, pas le comportement exact de Cloud CDN.

## Passer sur GCP

Le code de `catalogue/` se déploie tel quel. Ce qui l’entoure, vous l’écrivez en Terraform : c’est le cœur du TP.

1. Construire et pousser l’image, puis noter son digest :

```sh
REGION=europe-west9
PROJECT_ID=votre-projet
IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/streambox/catalogue:v1"
gcloud builds submit --tag "$IMAGE" catalogue
gcloud artifacts docker images describe "$IMAGE" --format='value(image_summary.digest)'
```

2. Copier les vidéos dans le bucket, en gardant le préfixe `media/` :

```sh
gcloud storage cp bucket/media/*.mp4 gs://VOTRE_BUCKET/media/
```

3. Dans votre URL map, `/media/*` va vers le backend bucket. L’API et la page d’accueil vont vers le backend du catalogue : faites-en la route par défaut, ou servez la page autrement et justifiez ce choix.

4. Pour que l’interface affiche le statut du cache comme en local, ajoutez au backend bucket l’en-tête de réponse personnalisé `X-Cache-Status: {cdn_cache_status}`. Sans lui, la page se rabat sur l’en-tête `Age`.

Ouvert directement par son URL `run.app`, le service affiche le catalogue mais pas les vidéos : c’est normal, elles ne passent pas par Cloud Run.

## Variables

| Variable | Rôle |
| --- | --- |
| `PORT` | Port d’écoute, fourni par Cloud Run (8080 par défaut). |
| `APP_VERSION` | Version affichée dans l’interface, pratique pour prouver quelle révision répond. |

## La carte du déploiement

En haut de l’interface, l’architecture cible est dessinée bloc par bloc. Chaque bloc s’allume selon ce que l’application constate elle-même, avec la preuve affichée dessous :

| Couleur | Sens |
| --- | --- |
| vert, « prouvé » | l’application l’a vérifié elle-même |
| orange, « à revoir » | ça fonctionne, mais c’est un anti-pattern connu |
| rouge, « en échec » | l’application a essayé et ça ne marche pas |
| pointillés, « pas encore détecté » | rien de visible pour l’instant |
| gris, « à prouver vous-même » | invisible depuis l’application : montrez-le dans la console |
| violet, « simulé en local » | l’équivalent local, en attendant le déploiement |

La carte constate, elle ne note pas : un bloc vert ne dit pas que votre choix est le bon, seulement qu’il est en place.

Pour StreamBox, le serveur vérifie Cloud Run et son identité ; le navigateur vérifie le passage par le Load Balancer, la route des médias, le cache et l’origine Cloud Storage. Aucun droit supplémentaire n’est nécessaire.
