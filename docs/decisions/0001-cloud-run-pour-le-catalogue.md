# ADR 0001 : Choix de Google Cloud Run pour l'API Catalogue

* **Statut :** Accepté
* **Date :** Octobre 2026
* **Décideurs :** Équipe StreamBox (Groupe 1)

## Contexte
L'API catalogue de StreamBox gère la consultation des vidéos et sert l'interface de démonstration. Le trafic est très variable (pics lors des connexions simultanées de classes d'élèves, périodes creuses la nuit et le week-end). L'équipe a besoin d'une solution de déploiement conteneurisée, sans gestion lourde d'infrastructure système.

## Alternatives Envisagées
1. **Google Compute Engine (VMs dédiées avec Instance Group)** :
   - *Avantages :* Contrôle total du système d'exploitation et de l'environnement réseau.
   - *Inconvénients :* Gestion des correctifs OS, lenteur de démarrage lors de l'autoscaling (plusieurs minutes), coût fixe permanent même sans trafic (pas de scale-to-zero).
2. **Google Kubernetes Engine (GKE Autopilot ou Standard)** :
   - *Avantages :* Standard industriel pour l'orchestration de conteneurs, portabilité multi-cloud.
   - *Inconvénients :* Complexité opérationnelle excessive pour un microservice unique, coût de cluster de management, surdimensionné pour le périmètre du projet.
3. **Google Cloud Run (v2) [Choix Retenu]** :
   - *Avantages :* Modèle Serverless entièrement managé, démarrage rapide en quelques secondes, mise à l'échelle automatique de 0 à `max_instances` (facturation exacte à la seconde d'utilisation), intégration native avec IAM et le Serverless NEG.

## Décision
Nous retenons **Google Cloud Run (v2)** avec un compte de service dédié et un plafond de 2 instances pour le laboratoire.

## Conséquences
- **Positives :** Coût minimal en période d'inactivité (scale-to-zero), maintenance système nulle, sécurité renforcée via isolation de conteneur gérée par Google.
- **Négatives / Limites :** Risque de latence lors d'un "cold start" (démarrage à froid). Ce risque est mitigé en production par un `min_instances = 1` si nécessaire.
