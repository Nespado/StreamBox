# Bootstrap StreamBox (Infrastructure de Démarrage)

Ce sous-projet Terraform permet d'initialiser les prérequis fondamentaux de la plateforme avant tout déploiement applicatif :
1. Le **bucket Cloud Storage pour le remote state** de Terraform avec versioning activé.
2. Le **Workload Identity Federation (WIF)** reliant GitHub Actions au projet GCP sans aucune clé JSON persistante dans le dépôt.
3. Le **compte de service CI/CD** avec les permissions IAM nécessaires pour exécuter les plans et applies en toute sécurité.

## Déploiement Initial (une seule fois)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

Noter les sorties `workload_identity_provider` et `ci_service_account_email` pour configurer les variables secrètes du pipeline GitHub Actions :
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`

## Lecture des images lors du déploiement

Le projet Terraform principal gère `google_project_iam_member.ci_artifact_reader`
dans `terraform/ci_artifact_registry.tf`. Il accorde au compte de déploiement
`roles/artifactregistry.reader` sur le projet : lecture des images et de leurs
métadonnées, sans écriture ni suppression. Cloud Run vérifie ce droit pour
déployer une nouvelle image, même si le compte possède déjà `roles/run.admin`.

Les modules catalogue et Grafana dépendent de cette liaison. Elle est créée par
GitHub Actions grâce au droit `roles/resourcemanager.projectIamAdmin` déjà accordé
par le bootstrap. Ne pas gérer la même liaison une seconde fois dans ce bootstrap.
Si la propagation IAM retarde le premier déploiement, relancer le workflow après
quelques minutes ; aucun apply local n'est nécessaire.
