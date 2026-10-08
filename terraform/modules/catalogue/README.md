# Module Terraform : catalogue

## Responsabilité

Ce module déploie le microservice de catalogue StreamBox sur **Google Cloud Run (v2)**. Il fournit l'API REST (`/api/catalogue`) et sert l'interface web de démonstration.

### Principes de sécurité appliqués :
- **Moindre privilège** : Utilise un compte de service dédié (`google_service_account.catalogue`), sans clé JSON et sans permissions superflues.
- **Isolement réseau** : Le trafic entrant est restreint à `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`. Les requêtes directes vers l'URL `*.run.app` sont rejetées (HTTP 403), forçant impérativement le passage par l'Application Load Balancer externe.
- **Plafonnement des ressources** : Limite stricte de montée en charge (`max_instances`) pour maîtriser les coûts et le dimensionnement de laboratoire.

## Entrées (Variables)

| Nom | Type | Description | Défaut |
| --- | --- | --- | --- |
| `project_id` | `string` | Identifiant du projet GCP | Requis |
| `region` | `string` | Région de déploiement (ex. `europe-west9`) | Requis |
| `image` | `string` | URL complète de l'image Docker dans Artifact Registry | Requis |
| `service_name` | `string` | Nom du service Cloud Run | `"streambox-catalogue"` |
| `max_instances` | `number` | Plafond d'instances Cloud Run simultanées | `2` |

## Sorties (Outputs)

| Nom | Description |
| --- | --- |
| `service_name` | Nom du service Cloud Run (utilisé par le Serverless NEG du module `delivery`) |
| `region` | Région du service Cloud Run |
| `service_uri` | URL directe du service Cloud Run |
| `service_account_email` | Adresse email du compte de service applicatif dédié |

## Ressources créées

- `google_service_account.catalogue` : Compte de service dédié à l'exécution de l'API.
- `google_cloud_run_v2_service.catalogue` : Service Cloud Run v2 (1 vCPU, 512 MiB, scaling 0 à max_instances).
- `google_cloud_run_v2_service_iam_member.public_access` : Rôle `roles/run.invoker` pour `allUsers` (le filtrage d'accès public se faisant via le Load Balancer).
