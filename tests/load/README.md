# Essai client et preuve Grafana

Workflow manuel **Essai client - 1, 5 et 10 utilisateurs**, sur `main` uniquement.
Activer l'entrée `execute` pour autoriser le trafic. Pas de déclenchement au push.

- Cible fixe : `https://streambox.chaleonm.ovh` ; API `/api/catalogue` et média `/media/demo-1.mp4`.
- 1 utilisateur pendant 120 s, puis 5 et 10 pendant 60 s chacun : 4 minutes actives.
- Une paire API/média par utilisateur toutes les 5 s, décalage de 50 ms par utilisateur.
- 408 GET attendus + 1 HEAD préalable. Limites : 450 GET, 10 Mio de corps reçus, réponse < 1 Mo, délai de 5 s et échéance globale.
- Arrêt sur 3 erreurs consécutives ou > 5 % à partir de 20 réponses. Toute réponse non 2xx compte comme erreur. Pas de redirections ni de rattrapage en rafale.
- Les plafonds d'octets se vérifient par bloc de lecture : quelques blocs déjà en vol peuvent dépasser le seuil avant l'arrêt.

Le runner mesure la durée complète de chaque requête. Ce sont des mesures côté
client de test, pas des visiteurs réels ni des temps de traitement Cloud Run.
Le runner GitHub peut avoir un réseau différent du PC utilisé pour les essais précédents.

## Courbes Grafana

Le dashboard provisionné `streambox-client-test` utilise trois métriques personnalisées
déclarées dans Terraform : moyenne des latences de chaque cycle de 5 s, utilisateurs
configurés, et p95 exact de chaque palier. Les moyennes ne sont pas des p95.
Les erreurs restent dans les fichiers bruts ; les latences affichées portent sur les
réponses réussies. Aucun point manquant n'est transformé en zéro.

L'identifiant d'essai est `GITHUB_RUN_ID-GITHUB_RUN_ATTEMPT`. Le renseigner dans
« Essai GitHub » et choisir la période indiquée par `protocol.json` / `summary.json`.
Les écritures vers Cloud Monitoring sont asynchrones, hors chronométrage des requêtes.
Le compte CI possède déjà `roles/monitoring.admin` ; le compte Grafana reste en lecture.
Le bouton navigateur de 60 s est indépendant : il n'envoie pas ces métriques.

Les artefacts Actions contiennent protocole, horodatages, chaque requête, p95 et points
publiés pendant 30 jours. Télécharger l'artefact pour la soutenance avant expiration.
Utiliser les chiffres du même essai pour les barres et la capture Grafana.

## Vérifications sans trafic

```sh
python -m unittest discover -s tests/load -p "test_*.py"
```

La publication utilise l'API Cloud Monitoring `projects.timeSeries.create` et les
requêtes Grafana utilisent son interface PromQL. Les séries ont au minimum 5 secondes
entre points. Les identifiants Google ne sont ni inclus dans les artefacts ni affichés.

Sources :
- https://docs.cloud.google.com/monitoring/custom-metrics/creating-metrics
- https://docs.cloud.google.com/monitoring/promql
