# ADR 0002 : Distribution des Médias via Cloud CDN et Backend Bucket Cloud Storage

* **Statut :** Accepté
* **Date :** Octobre 2026
* **Décideurs :** Équipe StreamBox (Groupe 1)

## Contexte
La diffusion de fichiers multimédias volumineux (vidéos de démonstration de plusieurs mégaoctets, ou vidéos réelles de 1 Go) génère une bande passante considérable. Le problème initial de StreamBox résidait dans le ralentissement de l'API lorsque plusieurs classes téléchargeaient des vidéos en simultané.

## Alternatives Envisagées
1. **Diffusion par l'API (Stream dans le code Node.js de Cloud Run)** :
   - *Avantages :* Contrôle programmatique simple de chaque requête de média.
   - *Inconvénients :* Saturation immédiate de la mémoire et du CPU de l'instance Cloud Run, limitation par la bande passante du conteneur, coût de CPU/RAM inutilement facturé pour du simple relais d'octets.
2. **Reverse Proxy Nginx dédié sur Compute Engine avec cache local** :
   - *Avantages :* Configuration très fine des règles de cache et de rate limiting.
   - *Inconvénients :* Gestion d'un serveur étatique (disques persistants pour le cache), goulot d'étranglement réseau sur une seule machine/région, pas de distribution mondiale à l'Edge.
3. **Backend Bucket Cloud Storage avec Cloud CDN [Choix Retenu]** :
   - *Avantages :* Découplage total de l'API, les octets sont servis directement par l'infrastructure mondiale de Google (points de présence Edge). Réduction drastique des accès à l'origine grâce au cache (`CACHE_ALL_STATIC`), prise en charge native des requêtes HTTP Range (reprise de lecture et seek vidéo).

## Décision
Nous retenons le couple **Cloud Storage (Bucket STANDARD) + Backend Bucket Load Balancer avec Cloud CDN activé**.

## Conséquences
- **Positives :** L'API catalogue n'est plus jamais ralentie par les téléchargements vidéos. Les vidéos populaires sont servies en quelques millisecondes avec un coût de transfert réseau réduit (tarif CDN inférieur au trafic sortant classique).
- **Négatives / Limites :** L'invalidation du cache nécessite un appel API ou un délai de TTL. Les vidéos sont en accès direct via le CDN sans authentification par jeton individuel (en production, une extension avec Cloud CDN Signed URLs ou Signed Cookies serait nécessaire pour les contenus réservés).
