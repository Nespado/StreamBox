# StreamBox | Insset GCP M1 2026 (Groupe 1)

Plateforme de diffusion de vidéos pédagogiques hautement scalable sur **Google Cloud Platform (GCP)**, orchestrée avec **Terraform**, sécurisée au moindre privilège et surveillée par **Cloud Monitoring** et **Grafana**.

---

## 1. Vue d'Ensemble du Projet

* **Projet GCP :** `streambox-insset-m1-2026`
* **Région principale :** `europe-west9` (Paris)
* **Point d'entrée :** Application Load Balancer externe global HTTP/HTTPS (`streambox.chaleonm.ovh`)
* **Couche applicative :** Microservice catalogue sur Cloud Run v2 (Serverless NEG, ingress restreint au Load Balancer)
* **Couche média & cache :** Backend Bucket GCS (`STANDARD`) accéléré par Cloud CDN (`CACHE_ALL_STATIC`)
* **Observabilité :** Dashboard Cloud Monitoring (11 métriques), 2 politiques d'alerte email, sink Cloud Logging vers GCS (`COLDLINE`), stack locale Prometheus / Grafana.

---

## 2. Structure du Dépôt

```text
.
├── .github/workflows/          # Pipelines CI/CD GitHub Actions (WIF fédéré)
│   ├── terraform-ci.yml        # Lint, fmt, validate, unit test, et plan
│   ├── terraform-apply.yml     # Apply avec approbation et smoke test nominal
│   └── terraform-destroy.yml   # Destruction approuvée et inventaire résiduel
├── catalogue/                  # Code Node.js du catalogue (Cloud Run)
├── local/                      # Émulation locale Nginx et script ffmpeg
├── docs/                       # Livrables et documentation d'architecture
│   ├── cadrage.md              # Étape 01 : Cadrage, hypothèses, volumes et critères
│   ├── architecture.md         # Étape 02 : Flux détaillés et découpage modulaire
│   ├── architecture.mmd        # Schéma d'architecture Mermaid
│   └── decisions/              # Architecture Decision Records (ADR)
│       ├── 0001-cloud-run-pour-le-catalogue.md
│       ├── 0002-cloud-cdn-et-backend-bucket-pour-les-medias.md
│       └── 0003-serverless-neg-et-alb.md
├── monitoring/                 # Stack locale Prometheus & Grafana (Stackdriver exporter)
│   ├── compose.yml
│   └── grafana/dashboards/streambox.json
├── terraform/                  # Code Infrastructure-as-Code
│   ├── bootstrap/              # Bootstrap WIF & Remote State bucket (cycle séparé)
│   ├── modules/                # Modules réutilisables et documentés
│   │   ├── buckets/            # Buckets GCS (media et archives logs)
│   │   ├── catalogue/          # Service Cloud Run v2 et compte IAM dédié
│   │   ├── delivery/           # Load Balancer, NEG, URL Map, IP, Certificat SSL
│   │   ├── media/              # Backend Bucket Cloud CDN et permissions de lecture
│   │   └── observability/      # Dashboard, alertes email, sink logs, Prometheus SA
│   ├── tests/                  # Tests unitaires Terraform (observability.tftest.hcl)
│   ├── main.tf                 # Assemblage des modules
│   ├── variables.tf            # Variables globales
│   ├── outputs.tf              # Sorties d'infrastructure
│   └── providers.tf            # Backend GCS et provider Google
└── tests/                      # Tests automatisés
    └── smoke/
        ├── smoke_test.sh       # Vérification du parcours nominal via LB
        └── negative_test.sh    # Vérification des erreurs et refus attendus (403 direct)
```

---

## 3. Lancement Local (Sans GCP)

Pour tester l'application avant tout déploiement :
```bash
docker compose up --build
```
Ouvrir ensuite [http://localhost:8080](http://localhost:8080).
Nginx simule l'Application Load Balancer et le cache CDN (`local/edge.conf`).

---

## 4. Déploiement Terraform

### A. Initialisation et validation locale

```bash
# Vérification du formatage
terraform -chdir=terraform fmt -check -recursive

# Initialisation sans accès au cloud (validation syntaxe)
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate

# Tests unitaires des modules
terraform -chdir=terraform test
```

### B. Déploiement sur GCP avec Remote State

```bash
# Initialisation avec le backend distant GCS
terraform -chdir=terraform init

# Visualisation du plan d'exécution
terraform -chdir=terraform plan

# Application des changements
terraform -chdir=terraform apply
```

---

## 5. Tests et Vérification du Parcours

Une fois le Load Balancer déployé :

```bash
# 1. Parcours nominal (Health check, API catalogue, CDN Hit/Miss)
./tests/smoke/smoke_test.sh https://streambox.chaleonm.ovh

# 2. Tests négatifs (Méthode non autorisée 405, 404, et rejet d'accès direct Cloud Run 403)
./tests/smoke/negative_test.sh https://streambox.chaleonm.ovh "<URL_DIRECTE_RUN_APP>"
```

---

## 6. Pipeline CI/CD Automatisé

La CI s'authentifie auprès de Google Cloud **sans aucune clé JSON** en utilisant **Workload Identity Federation (WIF)** :
* **Pull Requests & Branches :** Vérification automatique du formatage, validation, tests unitaires, et génération d'un `terraform plan` privé archivé en artefact.
* **Branche Main :** Application contrôlée du plan avec vérification post-déploiement par le script de smoke test.
* **Destruction :** Déclenchement manuel sous approbation explicite (`DESTROY-STREAMBOX`) avec inventaire des ressources restantes.

---

## 7. Observabilité et Suivi

* **Cloud Monitoring :** Dashboard natif comprenant 11 graphiques (latence p95, taux d'erreurs 5xx, hit/miss Cloud CDN, octets distribués).
* **Alertes & Archivage :** Deux politiques surveillant le taux d'erreur (> 1% sur 5 min avec min. 100 requêtes) et la latence (> 1 000 ms), avec sink vers bucket Coldline (`terraform/modules/observability/README.md`).
* **Grafana sur Cloud Run :** Déployé et accessible à l'adresse [StreamBox Monitoring](https://streambox.chaleonm.ovh/monitoring/) (voir `terraform/modules/grafana/README.md`).
* **Stack locale :** Guide de monitoring local disponible dans [monitoring/README.md](monitoring/README.md).
* **Preuves et Essais de charge :** Protocoles de test (charge, cache, alertes, reprise) et résultats horodatés documentés dans [validation/README.md](validation/README.md).
