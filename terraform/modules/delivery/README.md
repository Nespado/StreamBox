# Module Terraform : delivery

## Responsabilité

Ce module implémente le point d'entrée unique et la distribution réseau globale de StreamBox via un **Application Load Balancer (ALB) externe global** :
1. Crée un **Serverless Network Endpoint Group (NEG)** raccordé au service Cloud Run du catalogue.
2. Crée un **Backend Service** avec journalisation complète des requêtes (`log_config`, sample rate 1.0).
3. Configure l'**URL Map** pour aiguiller le trafic :
   - `/media/*` est routé vers le **Backend Bucket CDN** (fichiers vidéos).
   - Les autres chemins (dont `/` et `/api/*`) sont routés par défaut vers le **Backend Service Cloud Run** (catalogue et interface).
4. Alloue une **adresse IP publique globale statique**.
5. Gère la terminaison SSL via un **certificat SSL géré par Google** (`google_compute_managed_ssl_certificate`).
6. Met en place les **Forwarding Rules HTTP (port 80)** et **HTTPS (port 443)** avec redirection automatique HTTP vers HTTPS configurable.

## Entrées (Variables)

| Nom | Type | Description | Défaut |
| --- | --- | --- | --- |
| `project_id` | `string` | Identifiant du projet GCP | Requis |
| `region` | `string` | Région où réside le service Cloud Run | Requis |
| `cloud_run_service_name` | `string` | Nom du service Cloud Run à associer au Serverless NEG | Requis |
| `backend_bucket_id` | `string` | Identifiant du Backend Bucket fourni par le module `media` | Requis |
| `name_prefix` | `string` | Préfixe appliqué aux noms de ressources | `"streambox"` |
| `domain_name` | `string` | Domaine FQDN pour le certificat HTTPS (ex. `streambox.chaleonm.ovh`) | Requis |
| `enable_https_redirect` | `bool` | Active la redirection automatique HTTP -> HTTPS | `false` |

## Sorties (Outputs)

| Nom | Description |
| --- | --- |
| `ip_address` | Adresse IPv4 publique globale du Load Balancer |
| `url_map_id` | Identifiant de l'URL Map GCP |
| `http_url` | URL en clair `http://<domain_name>` |
| `https_url` | URL sécurisée `https://<domain_name>` |

## Dépendances avec les autres modules

```text
[module.catalogue]  ---> cloud_run_service_name, region ---> [module.delivery]
[module.media]      ---> backend_bucket_id              ---> [module.delivery]
```
