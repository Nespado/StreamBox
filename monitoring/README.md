# Prometheus et Grafana en local

Cette stack lit les métriques du projet GCP via l'exporter Stackdriver, les conserve dans Prometheus et les affiche dans Grafana. Elle n'ajoute pas de route `/metrics` au catalogue.

```text
Cloud Monitoring → exporter → Prometheus → Grafana
Cloud Logging → sink → bucket d'archives
Cloud Monitoring → politiques d'alerte → email
```

Les alertes restent dans Cloud Monitoring : elles continuent à fonctionner lorsque ton PC est éteint. Prometheus et Grafana ne collectent que lorsque Docker et cette stack fonctionnent.

## Prérequis

- Docker Desktop démarré en mode conteneurs Linux.
- Infrastructure GCP et [module observability](../terraform/modules/observability/README.md) déployés, avec du trafic.
- CLI gcloud installée et accès au compte `streambox-metrics-reader@streambox-insset-m1-2026.iam.gserviceaccount.com`.

Ce compte reçoit `roles/monitoring.viewer` via Terraform. Pour l'utiliser sans clé privée, un administrateur doit accorder à ton identité GCP `roles/iam.serviceAccountTokenCreator` **sur ce compte de service**, pas sur tout le projet. Le module n'accorde pas ce droit automatiquement à une personne.

## Authentification sans clé de service

Depuis la racine du dépôt, créer des identifiants ADC dans un dossier local ignoré par Git :

```powershell
$previousGcloudConfig = $env:CLOUDSDK_CONFIG
$env:CLOUDSDK_CONFIG = Join-Path $PWD.Path "monitoring/.gcloud"
try {
    gcloud auth login
    gcloud auth application-default login --impersonate-service-account=streambox-metrics-reader@streambox-insset-m1-2026.iam.gserviceaccount.com --disable-quota-project
} finally {
    $env:CLOUDSDK_CONFIG = $previousGcloudConfig
}
```

Le fichier attendu est `monitoring/.gcloud/application_default_credentials.json`. Il contient des identifiants personnels sensibles utilisés pour obtenir des jetons temporaires du compte de service : ne pas le partager ni le committer. Il sera monté en lecture seule dans l'exporter. [ADC avec impersonation](https://docs.cloud.google.com/docs/authentication/set-up-adc-local-dev-environment).

## Configuration et démarrage

Copier `.env.example` une seule fois, sans écraser une configuration existante :

```powershell
if (-not (Test-Path monitoring/.env)) {
    Copy-Item monitoring/.env.example monitoring/.env
}
```

Dans `monitoring/.env` :

- Renseigner `GOOGLE_APPLICATION_CREDENTIALS` avec le chemin absolu du fichier ADC, avec des slashs `/` sous Windows.
- Choisir `GRAFANA_ADMIN_PASSWORD`.
- Vérifier projet, région, service et URL map.

Exemple de chemin : `C:/Users/swanndefossez/Desktop/streambox/StreamBox/monitoring/.gcloud/application_default_credentials.json`.

```powershell
docker compose --env-file monitoring/.env -f monitoring/compose.yml config --quiet
docker compose --env-file monitoring/.env -f monitoring/compose.yml up -d
docker compose --env-file monitoring/.env -f monitoring/compose.yml ps
```

Ne pas utiliser `config` sans `--quiet` dans une capture partagée : il peut afficher le mot de passe interpolé.

- [Grafana](http://127.0.0.1:3000) : utilisateur `admin` par défaut, mot de passe du fichier local, dossier **StreamBox**.
- [Prometheus](http://127.0.0.1:9090) : vérifier la cible `streambox-gcp` dans Status / Target health.
- [Exporter](http://127.0.0.1:9255/metrics) : inspection ponctuelle des noms et labels de métriques.

Les ports écoutent seulement sur `127.0.0.1`. Le dashboard et la source Prometheus sont provisionnés automatiquement. Si le projet ou les noms changent dans `.env`, adapter aussi les champs du dashboard Grafana.

Le mot de passe initial Grafana ne s'applique qu'à la création de sa base. Le changer dans `.env` après le premier lancement ne modifie pas le compte déjà enregistré.

## Vérifications

Après quelques cycles de collecte, vérifier les panneaux **Collecte — exporter joignable** (1 attendu) et **Collecte — erreur API GCP** (0 attendu). Un exporter joignable peut néanmoins échouer à lire GCP.

```powershell
docker compose --env-file monitoring/.env -f monitoring/compose.yml logs --tail=100 exporter
docker compose --env-file monitoring/.env -f monitoring/compose.yml logs --tail=100 prometheus grafana
```

En cas de 403, vérifier l'identité utilisée, le droit d'impersonation, le rôle Monitoring et les API activées. En cas de courbes vides, vérifier projet, noms, région, présence de trafic et délai de publication.

L'exporter relit uniquement les familles de métriques utiles, avec un filtre sur le service et l'URL map. Les DELTA sont accumulés en compteurs en mémoire pour les fonctions `rate()` ; le redémarrage de l'exporter réinitialise ces compteurs. La collecte tient compte du délai d'ingestion annoncé par GCP. Les premières minutes et les séries peu actives peuvent être imprécises : utiliser le dashboard natif Cloud Monitoring et les résultats du générateur de charge pour le bilan du labo. [Fonctionnement de l'exporter](https://github.com/prometheus-community/stackdriver_exporter/tree/v0.19.0).

Les graphiques de débit Grafana sont en **octets/s**, tandis que le dashboard GCP affiche des **octets par fenêtre de 60 secondes**. Une requête vide ne doit pas être présentée comme zéro erreur ou zéro trafic.

## Arrêt et conservation

```powershell
docker compose --env-file monitoring/.env -f monitoring/compose.yml down
```

Cette commande conserve les volumes. Prometheus garde au maximum 7 jours de données, avec une limite de taille TSDB de 1 Go ; cette limite ne couvre pas tous les fichiers temporaires/WAL. La base Grafana est également persistée. Laisser le PC allumé n'est pas nécessaire pour les alertes GCP.

Les fichiers de dashboard et de provisioning sont la source de référence : les modifier dans le dépôt. Cette stack locale n'est pas un hébergement Grafana permanent pour le groupe.

## Versions et validation

Images fixées : Prometheus `v3.15.0`, Grafana `13.2.3`, exporter `v0.19.0`.

La configuration Compose et la configuration Prometheus ont été validées. Un test Docker isolé a vérifié le chargement des 12 panneaux Grafana, la connexion à Prometheus et l'acceptation des 12 requêtes PromQL. Il n'a utilisé aucune donnée GCP ni envoyé d'email ; ces vérifications restent à faire après déploiement.
