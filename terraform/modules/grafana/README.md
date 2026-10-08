# Grafana serverless

Ce module déploie l'image Grafana du projet sur Cloud Run, avec le frontend
officiel Google comme proxy d'authentification vers l'API Managed Service for
Prometheus. Les deux conteneurs appartiennent au même service ; seul Grafana
écoute sur le port d'entrée 8080. Le proxy sur 9090 utilise les identifiants
temporaires du compte de service attaché à Cloud Run. Aucun PC, VM, disque
Prometheus ni clé JSON n'est nécessaire à son fonctionnement.

## Ressources et droits

- Un compte de service dédié, avec `roles/monitoring.viewer` dans le projet.
- Deux secrets Secret Manager répliqués dans la région choisie : le mot de passe
  `admin` et la clé interne Grafana. Le compte n'a `secretAccessor` que sur ces secrets.
- Un Cloud Run à 0 instance minimum et 1 maximum au niveau du service, avec
  affinité de session, 20 requêtes simultanées et un timeout de 120 secondes.
- Grafana : 1 vCPU et 512 Mio ; proxy : 1 vCPU et 256 Mio. CPU alloué pendant les
  requêtes, pas de collecte ni de renouvellement périodique nécessitant du CPU inactif.
- L'ingress est limité au trafic interne et au Load Balancer. Le droit
  `run.invoker` à `allUsers` permet au LB d'appeler le service ; Grafana demande
  ensuite sa propre authentification. L'URL `run.app` n'est pas une entrée publique
  de remplacement.

Le module `delivery` utilise les sorties `service_name` et `region` pour créer
le Serverless NEG, le backend sans CDN et les routes `/monitoring` et
`/monitoring/*`. Le catalogue reste la destination par défaut et `/media/*`
conserve son backend bucket.

## Versions et paramètres

Terraform **>= 1.11, < 2**, Google **8.5.0**, Random **3.7.2**. Les deux images
sont fixées par digest. L'image Grafana publiée porte le tag `13.2.3-1` ; le
proxy correspond à `frontend:v0.15.3-gke.0`, issu de l'exemple officiel Google.

| Entrée | Rôle |
| --- | --- |
| `project_id`, `region` | Projet et région GCP. |
| `service_name` | Nom Cloud Run et compte de service, `streambox-grafana` par défaut. |
| `image` | Image Grafana dans Artifact Registry, avec digest obligatoire. |
| `proxy_image` | Image du proxy Google, avec digest obligatoire. |
| `public_url` | URL HTTPS terminée par `/monitoring/`. |
| `secret_rotation` | Entier, 1 par défaut ; incrémenter pour renouveler les deux secrets. |

Les sorties ne contiennent que l'URL, les identifiants et le nom du secret du
mot de passe. L'API Cloud Run, IAM et Monitoring doivent déjà être activées pour
le projet ; le module active Secret Manager sans le désactiver à la destruction.

## Secrets et reproductibilité

Les mots de passe sont générés par `ephemeral.random_password` et transmis avec
`secret_data_wo`. Leurs valeurs ne sont pas enregistrées dans le plan ni le state
Terraform. Le state contient les références et les versions des secrets.
Terraform doit rester au moins en version 1.11 pour ces arguments write-only.

`secret_rotation` contrôle les mises à jour : une nouvelle exécution Terraform
ne doit pas renouveler automatiquement un secret existant. Son incrément crée
de nouvelles versions et une nouvelle révision Cloud Run qui les référence
explicitement. Les versions remplacées suivent la politique `DELETE`.

## Déploiement depuis la racine du dépôt

L'image Grafana doit déjà être publiée et le certificat HTTPS doit être `ACTIVE`.
La configuration racine active désormais `enable_https_redirect` par défaut.
L'exposition de Grafana est refusée par une précondition si cette redirection
est désactivée : elle empêche de présenter le formulaire de connexion en HTTP.

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform validate
terraform -chdir=terraform test
terraform -chdir=terraform plan -out=grafana-review.tfplan
```

Vérifier les actions avant d'appliquer ce plan, puis :

```powershell
terraform -chdir=terraform apply grafana-review.tfplan
```

Le plan vérifié le 8 octobre 2026 prévoit **13 créations, 2 mises à jour, aucune
suppression** : 11 ressources du module Grafana, le NEG et le backend Grafana,
puis le routage `/monitoring` et la redirection HTTP vers HTTPS. Les buckets,
le catalogue et le module observability n'ont aucune action prévue. Ce décompte
est un constat ponctuel : recontrôler le plan si l'état partagé ou le code change.
Le fichier de plan est ignoré par Git.

Après déploiement, ouvrir `https://streambox.chaleonm.ovh/monitoring/`, utiliser
`admin` et récupérer le mot de passe dans Secret Manager avec une identité autorisée :

```powershell
gcloud secrets versions access latest --secret=streambox-grafana-admin-password --project=streambox-insset-m1-2026
```

Cette commande affiche un secret : le consulter dans son terminal, sans le
committer ni le joindre aux captures du rapport. La clé interne Grafana n'a pas
besoin d'être consultée par les utilisateurs.

## Vérifications

Les tests Terraform utilisent un provider Google simulé : ingress, borne
d'instances, secrets injectés, proxy interne, routes avec et sans Grafana, refus
du HTTP et absence de CDN sur le backend Grafana. Les tests observability existants
restent inclus. Les huit tests passent.

Le test Docker de l'image vérifie le provisioning sur deux instances neuves.
Un test d'intégration ponctuel a aussi validé Grafana → frontend Google → API GCP
avec des identifiants ADC de développement montés en lecture seule ; les
conteneurs temporaires ont été supprimés. Cela ne valide pas encore l'identité
Cloud Run déployée ni l'accès depuis le Load Balancer.

Après apply, vérifier : redirection HTTP, page de connexion HTTPS, refus
d'accès anonyme au dashboard, datasource « Successfully queried the Prometheus
API », données du catalogue, puis données CDN après un peu de trafic média.
Des séries absentes ne prouvent pas un trafic nul. Vérifier aussi que les routes
catalogue et médias continuent de répondre et que les alertes GCP restent actives.

## Limites assumées pour le labo

Les métriques sont conservées chez Google ; le proxy ne les stocke pas. Les
dashboards et la datasource sont recréés depuis l'image. La base SQLite de
Grafana reste éphémère : une nouvelle instance peut perdre sessions, utilisateurs
ajoutés et préférences. Le maximum d'une instance et l'affinité n'offrent aucune
garantie de persistance ni d'unicité pendant un remplacement. Une reconnexion
peut être nécessaire après un démarrage à froid ou un déploiement.

Pour conserver durablement des comptes ou modifications de l'interface, il
faudrait une base externe prise en charge par Grafana. Les alertes email restent
dans Cloud Monitoring et les archives dans GCS ; Grafana ne les remplace pas.

Documentation : [image Grafana](../../../monitoring/grafana-cloudrun/README.md),
[proxy Google](https://docs.cloud.google.com/stackdriver/docs/managed-prometheus/query-api-ui),
[valeurs write-only Terraform](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only).
