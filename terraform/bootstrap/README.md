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
