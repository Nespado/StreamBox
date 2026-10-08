# Architecture Technique StreamBox (Étape 02)

Ce document décrit l'architecture cible déployée pour le projet **StreamBox**, le détail des flux de données de bout en bout, et le découpage modulaire en Infrastructure-as-Code (Terraform).

---

## 1. Schéma d'Architecture Cible

Consulter le fichier [docs/architecture.mmd](architecture.mmd) pour le diagramme au format Mermaid.

```text
                     +---------------------------------------+
                     |         Spectateur / Navigateur       |
                     +---------------------------------------+
                                         | HTTPS (80/443)
                                         v
                     +---------------------------------------+
                     | Application Load Balancer Externe     |
                     | Global IP + SSL Managed + URL Map     |
                     +---------------------------------------+
                            /                         \
         /api/* ou /       /                           \  /media/*
                          v                             v
            +------------------------+      +------------------------+
            | Serverless NEG         |      | Backend Bucket         |
            +------------------------+      +------------------------+
                          |                             |
                          v                             v
            +------------------------+      +------------------------+
            | Cloud Run (Catalogue)  |      | Cloud CDN (Edge Cache) |
            | Ingress: INTERNAL_LB   |      +------------------------+
            +------------------------+                  |
                                                        v (si Cache MISS)
                                            +------------------------+
                                            | Cloud Storage (Médias) |
                                            +------------------------+
```

---

## 2. Description Flux par Flux

### Flux 1 : Consultation du catalogue et navigation web (`/` et `/api/*`)
1. Le client effectue une requête HTTPS vers le domaine `streambox.chaleonm.ovh`.
2. La requête frappe l'adresse IP globale et la `google_compute_global_forwarding_rule`.
3. Le proxy HTTPS termine la connexion TLS avec le certificat managé Google.
4. L'**URL Map** constate que le chemin correspond à l'interface d'accueil ou à `/api/*` et oriente la requête vers le **Backend Service** du catalogue.
5. Le Backend Service achemine la requête via le **Serverless NEG** vers le service **Cloud Run v2** (`streambox-catalogue`).
6. Cloud Run traite la requête sous son compte de service dédié et renvoie la réponse JSON ou les assets web statiques.
7. *Sécurité :* Le service Cloud Run bloque tout accès direct qui ne proviendrait pas de ce Load Balancer (`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`).

### Flux 2 : Demande de vidéo et distribution Edge (`/media/*`)
1. Le navigateur demande un fichier vidéo (ex. `/media/video-1-720p.mp4`).
2. L'**URL Map** intercepte le préfixe `/media/*` et l'aiguille vers le **Backend Bucket CDN** (`streambox-backend-media`).
3. **Cas A - Cache HIT :**
   - Cloud CDN dispose déjà de l'objet dans le point de présence Edge le plus proche de l'utilisateur.
   - La vidéo est servie immédiatement au client avec l'en-tête `X-Cache-Status: HIT`.
   - Aucun octet n'est demandé à l'origine Cloud Storage, garantissant une latence minimale et aucun coût de lecture GCS.
4. **Cas B - Cache MISS :**
   - Le CDN interroge le bucket Cloud Storage sous-jacent (`bucket-insset-streambox-media`).
   - L'objet est récupéré et renvoyé au client avec l'en-tête `X-Cache-Status: MISS`.
   - L'objet est stocké en cache selon la politique de TTL (1 heure client/défaut, 24 heures max).

### Flux 3 : Observabilité, Alertes et Archivage
1. **Métriques :** Le Load Balancer et Cloud Run émettent nativement des métriques vers Cloud Monitoring (taux de requêtes, latence, codes HTTP, cache hit/miss).
2. **Alertes :** Deux politiques d'alerte surveillent en continu le ratio de 5xx et la latence p95, et notifient par email via un canal configuré.
3. **Export de journaux :** Un sink Cloud Logging (`streambox-log-archive`) filtre les logs HTTP et applicatifs et les écrit par lots dans le bucket GCS Coldline (`bucket-insset-streambox-logs`) pour conservation économique.

---

## 3. Découpage Modulaire Terraform

L'infrastructure est découpée en **5 modules autonomes** dans `terraform/modules/` respectant le principe de responsabilité unique :

```text
terraform/
  main.tf                 # Assemblage des modules et passage des dépendances
  variables.tf            # Variables globales (ex. enable_https_redirect)
  outputs.tf              # Sorties de synthèse (IP, URLs, métriques observabilité)
  providers.tf            # Provider google et backend remote state GCS
  modules/
    buckets/              # Stockage objet GCS (media STANDARD, logs COLDLINE)
    catalogue/            # Service Cloud Run, compte de service IAM, ingress filtré
    media/                # Backend Bucket, Cloud CDN, règles de cache et lecture publique
    delivery/             # Application Load Balancer, NEG, URL Map, IP, Certificat SSL
    observability/        # Dashboard 11 widgets, 2 alertes email, sink logs, Prometheus reader
```

### Matrice des Dépendances entre Modules

| Module Source | Sortie Exposée | Module Consommateur | Variable Reçue |
| :--- | :--- | :--- | :--- |
| `module.bucket-media` | `name` | `module.media` | `bucket_name` |
| `module.bucket-logs` | `name` | `module.observability` | `log_archive_bucket_name` |
| `module.catalogue` | `service_name`, `region` | `module.delivery` | `cloud_run_service_name`, `region` |
| `module.media` | `backend_bucket_id` | `module.delivery` | `backend_bucket_id` |
| `module.delivery` | `url_map_name` (ou nom) | `module.observability` | `load_balancer_url_map_name` |
