# Cadrage du Projet StreamBox (Étape 01)

## 1. Contexte et Mission

L'équipe StreamBox confie l'infrastructure de sa plateforme de diffusion de vidéos pédagogiques pour préparer une campagne auprès d'établissements scolaires. 
Constat initial : le catalogue répondait bien, mais les lectures simultanées ralentissaient l'API car les flux vidéos transitaient par le serveur applicatif.

**Objectif du laboratoire :** Réaliser un démonstrateur d'infrastructure hautement scalable, découplant totalement l'API de la distribution des médias via Google Cloud Platform (GCP), automatisé avec Terraform, sécurisé, monitoré et chiffré.

---

## 2. Fiche d'Hypothèses

| Besoin ou Question | Réponse ou Hypothèse | Source / Confirmation | Preuve Prévue |
| :--- | :--- | :--- | :--- |
| **Séparation des flux** | Les fichiers vidéo volumineux ne doivent jamais transiter par le conteneur applicatif Cloud Run. | Brief client / Sujet | Requêtes `/media/*` aiguillées vers le Backend Bucket GCS par l'URL Map du Load Balancer. |
| **Mise en cache** | Les médias statiques doivent être mis en cache au plus près des utilisateurs via Cloud CDN. | Brief client / Équipe produit | En-tête `X-Cache-Status: HIT` lors des lectures répétées et métriques Cloud CDN. |
| **Sécurité d'accès API** | L'accès à Cloud Run doit être verrouillé pour forcer le passage par le Load Balancer. | Bonnes pratiques GCP / Sujet | Ingress configuré à `INTERNAL_LOAD_BALANCER` ; refus HTTP 403 sur URL directe `run.app`. |
| **Gestion des identités** | Aucun secret ou clé de compte de service ne doit être stocké dans Git. | Exigence de sécurité du module | Utilisation de Workload Identity Federation (WIF) pour la CI et ADC / Impersonation en local. |
| **Maîtrise budgétaire** | Le coût du laboratoire doit rester borné (< 25 €) avec alertes budget. | Équipe pédagogique | Suivi des alertes de facturation GCP et nettoyage des ressources (`terraform destroy`). |

---

## 3. Les Trois Critères de Réussite Validés

1. **Découplage strict des flux (Zero Data-Path Bottleneck)** :
   * *Critère :* 100 % des octets vidéos sont servis par le Backend Bucket / Cloud CDN. 0 octet vidéo ne transite par l'API Cloud Run.
   * *Vérification :* Constat dans les métriques réseau de Cloud Run (bande passante sortante limitée aux réponses JSON de quelques Ko) et inspection de l'URL Map.
2. **Efficacité de la distribution et du cache CDN** :
   * *Critère :* Taux de cache supérieur à 80 % sur les vidéos lors des lectures concurrentes, temps de réponse divisé d'au moins un facteur 3 entre un `MISS` et un `HIT`.
   * *Vérification :* En-tête `X-Cache-Status: HIT` renvoyé par le Load Balancer et tableau de bord Cloud Monitoring.
3. **Résilience et isolation de l'API sous trafic** :
   * *Critère :* L'API catalogue maintient un taux d'erreur 5xx inférieur à 1 % et une latence p95 inférieure à 500 ms lors des paliers de charge du labo (jusqu'à 10 utilisateurs simultanés).
   * *Vérification :* Graphiques Cloud Monitoring et absence de déclenchement des politiques d'alerte en régime nominal.

---

## 4. Périmètre du Laboratoire : Retenu vs Écarté

### Inclus dans le périmètre
- **Catalogue & UI :** Microservice conteneurisé déployé sur Cloud Run v2 avec compte de service dédié au moindre privilège.
- **Stockage objet :** Bucket Google Cloud Storage sécurisé en région `europe-west9` pour les médias, bucket Coldline pour l'archivage des logs.
- **Réseau & Edge :** Application Load Balancer externe global HTTP(S) avec Serverless NEG, routage URL Map, et certificat SSL managé.
- **Accélération :** Cloud CDN activé sur le backend bucket avec politique de mise en cache statique agressive.
- **Observabilité :** Dashboard Cloud Monitoring complet (11 métriques), 2 politiques d'alerte (erreurs et latence), sink d'export des journaux, stack locale Prometheus/Grafana.
- **Automatisation :** Déploiement 100 % Infrastructure-as-Code Terraform avec state distant GCS et pipeline CI/CD GitHub Actions fédéré (WIF).

### Volontairement écarté (hors périmètre)
- **Transcodage vidéo à la volée :** Les médias de test sont pré-encodés au format standard MP4. Aucun pipeline Transcoder API ou cluster FFmpeg n'est déployé.
- **Gestion des DRM / Chiffrement de flux :** Pas d'intégration Widevine / PlayReady / FairPlay.
- **Gestion des utilisateurs et abonnements :** Pas de base de données relationnelle (Cloud SQL/Spanner) ni de module d'authentification OAuth/Firebase Auth.
- **Frontend complexe :** Démonstrateur fourni par le kit HTML/JS statique sans framework lourd (React/Vue).

---

## 5. Volumes et Limite de Coût

* **Jeux d'essai du laboratoire :** 3 vidéos de test de moins de 1 Mo chacune dans le bucket.
* **Charges du laboratoire :** Paliers progressifs de 1, 5, puis 10 utilisateurs virtuels sur 5 minutes au maximum.
* **Volumes de référence pour la projection de coût annuelle :**
  - Catalogue cible : 2 000 vidéos pédagogiques d'une taille moyenne de 1 Go (2 To de stockage brut).
  - Audience cible : Plusieurs classes simultanées (~100 à 500 flux vidéo concurrents aux heures de pointe).
* **Plafond budgétaire du laboratoire :** Limite indicative fixée à 20-30 € sur le projet GCP de démonstration.
