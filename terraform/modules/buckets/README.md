# Module Terraform : buckets

## Responsabilité

Ce module gère la création des buckets Google Cloud Storage (GCS) pour le projet StreamBox, avec contrôle d'accès uniforme (`uniform_bucket_level_access`) et sélection de la classe de stockage (`STANDARD`, `COLDLINE`, etc.).

Il est utilisé pour :
- Le stockage des objets vidéo distribués par le CDN (`bucket-insset-streambox-media`, classe `STANDARD`).
- L'archivage à long terme des journaux Cloud Logging (`bucket-insset-streambox-logs`, classe `COLDLINE`).

## Entrées (Variables)

| Nom | Type | Description | Défaut |
| --- | --- | --- | --- |
| `name` | `string` | Nom unique du bucket GCS dans GCP | Requis |
| `bucket-class` | `string` | Classe de stockage (`STANDARD`, `NEARLINE`, `COLDLINE`, `ARCHIVE`) | `"STANDARD"` |

## Sorties (Outputs)

| Nom | Description |
| --- | --- |
| `name` | Nom du bucket créé |
| `url` | URI `gs://` du bucket |
| `self_link` | Lien d'auto-référence GCP du bucket |

## Ressources créées

- `google_storage_bucket.static` : Bucket GCS en région `europe-west9` avec `uniform_bucket_level_access = true`.
