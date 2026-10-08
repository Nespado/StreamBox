# ADR 0003 : Application Load Balancer Externe Global avec Serverless NEG

* **Statut :** Accepté
* **Date :** Octobre 2026
* **Décideurs :** Équipe StreamBox (Groupe 1)

## Contexte
StreamBox doit exposer à la fois des routes applicatives dynamiques (`/api/*`, `/`) et des contenus statiques lourds (`/media/*`) sous un nom de domaine unique (`streambox.chaleonm.ovh`), avec chiffrement TLS et haute disponibilité.

## Alternatives Envisagées
1. **Exposition directe Cloud Run avec domaine personnalisé et bucket public séparé (deux domaines distincts)** :
   - *Avantages :* Très simple à mettre en place, pas de coût de Load Balancer.
   - *Inconvénients :* Problèmes de CORS (Cross-Origin Resource Sharing) entre le lecteur web et le bucket, pas de nom de domaine unifié, impossibilité d'utiliser Cloud CDN sur le bucket sans Load Balancer externe, exposition publique non contrôlable de l'URL Cloud Run `*.run.app`.
2. **Classic Application Load Balancer (Régional)** :
   - *Avantages :* Coût légèrement inférieur dans certains cas.
   - *Inconvénients :* Moins performant pour une distribution mondiale, fonctionnalités de routage plus limitées, transition recommandée vers le modèle Global External ALB.
3. **Application Load Balancer Externe Global (HTTP/HTTPS) + Serverless NEG [Choix Retenu]** :
   - *Avantages :*
     * Point d'entrée unique (adresse Anycast IP globale).
     * Routage basé sur le chemin (URL Map) : sépare de manière étanche `/media/*` vers le bucket CDN et le reste vers Cloud Run.
     * Certificat SSL entièrement managé par Google avec renouvellement automatique.
     * Permet de fermer l'accès direct Cloud Run (`INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`) pour que tout le trafic passe obligatoirement par le Load Balancer.

## Décision
Nous retenons l'**Application Load Balancer externe global** couplé à un **Serverless Network Endpoint Group (NEG)** rattaché à Cloud Run, avec un certificat managé Google et une URL Map dédiée.

## Conséquences
- **Positives :** Expérience utilisateur fluide sous une seule origine, sécurité périmétrique complète (possibilité future d'ajouter Cloud Armor WAF sans refonte d'architecture), observabilité centralisée des logs HTTP.
- **Négatives / Limites :** Coût fixe mensuel de base pour les règles de transfert du Load Balancer (~18 $/mois), qui constitue le coût fixe principal du laboratoire GCP.
