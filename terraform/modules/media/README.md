# Module Terraform : media

## Responsabilité

Ce module configure la couche de distribution et de mise en cache des vidéos pour StreamBox :
1. Déclare un **Backend Bucket** pour l'Application Load Balancer connecté au bucket Cloud Storage contenant les fichiers vidéos.
2. Active et configure **Cloud CDN** avec des règles de cache adaptées aux contenus statiques lourds.
3. Injecte l'en-tête de réponse personnalisé `X-Cache-Status: {cdn_cache_status}` attendu par l'interface StreamBox pour afficher le statut du cache (`HIT`, `MISS`, etc.) en temps réel.
4. Accorde les droits de lecture publique sur les objets du bucket (`roles/storage.objectViewer`) pour permettre au CDN de distribuer les médias.

## Entrées (Variables)

| Nom | Type | Description | Défaut |
| --- | --- | --- | --- |
| `bucket_name` | `string` | Nom du bucket Cloud Storage contenant les vidéos | Requis |
| `name` | `string` | Nom de la ressource Backend Bucket CDN | `"streambox-backend-media"` |

## Sorties (Outputs)

| Nom | Description |
| --- | --- |
| `backend_bucket_id` | Identifiant du Backend Bucket (consommé par le module `delivery` pour l'URL Map) |
| `backend_bucket_self_link` | Lien d'auto-référence GCP du Backend Bucket |

## Politique de Cache (Cloud CDN)

- **Mode de cache** : `CACHE_ALL_STATIC`
- **Client TTL** : 3600 secondes (1 heure)
- **Default TTL** : 3600 secondes (1 heure)
- **Max TTL** : 86400 secondes (24 heures)
- **Negative Caching** : Activé (évite les tempêtes d'accès à l'origine en cas de 404 temporaire)
- **Serve While Stale** : 86400 secondes (résilience si l'origine devient temporairement inaccessible)

## Ressources créées

- `google_compute_backend_bucket.media` : Backend Bucket avec Cloud CDN et politique de cache.
- `google_storage_bucket_iam_member.public_read` : Droits de lecture objet public sur le bucket GCS.
