# Le bootstrap donne déjà à la CI le droit de gérer les liaisons IAM du projet.
# Ce droit de lecture est géré ici pour être installé par le workflow existant,
# avant le déploiement des services, sans apply local du bootstrap.
resource "google_project_iam_member" "ci_artifact_reader" {
  project = "streambox-insset-m1-2026"
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:streambox-ci-deployer@streambox-insset-m1-2026.iam.gserviceaccount.com"
}
