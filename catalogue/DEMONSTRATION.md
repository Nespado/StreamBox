# Démonstration : 10 utilisateurs pendant 60 secondes

Le panneau sous les chemins API/médias lance une simulation depuis le navigateur.
Il ne crée ni job GCP ni endpoint serveur de génération de charge. Il vise seulement
`/api/catalogue` et `/media/demo-1.mp4` sur le site ouvert.

## Déroulement à l’oral

1. Ouvrir le site et se connecter à Grafana avant la présentation.
2. Dans le panneau « Démonstration de charge », cliquer sur « Ouvrir Grafana ».
   Le lien sélectionne les 15 dernières minutes et un rafraîchissement de 30 s.
3. Revenir au site, lancer les 10 utilisateurs et noter l’heure affichée.
4. Montrer les compteurs du front pendant la minute, puis les panneaux Grafana
   « Catalogue — requêtes/s » et « Médias — requêtes par résultat de cache ».
5. Attendre quelques minutes si le pic n’est pas encore visible. Les métriques GCP
   ne sont pas instantanées ; un rafraîchissement fréquent ne supprime pas ce délai.
6. Exporter le JSON si une preuve de cette exécution est nécessaire.

Garder le site ouvert. Une seconde fenêtre visible à côté de Grafana est préférable :
un navigateur peut ralentir les timers d’un onglet en arrière-plan. Les cycles manqués
ne sont pas rattrapés en rafale ; le total peut donc être inférieur à 240 requêtes.
La fermeture du site, le bouton Arrêter et la limite de durée annulent la simulation.
Une page suspendue ne génère pas de trafic et vérifie l’échéance à sa reprise.

## Protocole et limites

- 10 utilisateurs, 60 secondes, une paire API/vidéo par utilisateur toutes les 5 s.
- Au plus 120 GET API + 120 GET vidéo, plus un HEAD préalable de contrôle de taille.
- Requêtes légèrement décalées de 50 ms entre utilisateurs, comme l’essai du labo.
- Petit média fixé à `demo-1.mp4`, taille connue strictement inférieure à 1 Mo.
- Arrêt à 8 Mo de corps de réponses lus, dès qu’une réponse atteint 1 Mo,
  après 3 erreurs consécutives ou plus de 5 % d’erreurs à partir de 20 réponses.
  Le seuil en octets est détecté à réception d’un bloc ; un bloc déjà reçu peut
  dépasser le seuil avant l’annulation. Le compteur montre les octets effectivement lus.
- Délai de 5 s par requête ; aucun suivi de redirection et aucune cible configurable.
- Un seul lancement actif par page ; Web Locks empêche aussi deux lancements
  dans les onglets du même navigateur/origine lorsque disponible. Ce verrou n’est
  pas une limite globale entre différents ordinateurs.
- Le cache navigateur est évité sans changer le chemin du fichier ni ajouter une
  clé aléatoire. Les HIT affichés sont ceux annoncés par `X-Cache-Status` du CDN.
- Les latences p95 du front portent sur les réponses réussies et incluent réseau,
  TLS et téléchargement. Elles diffèrent du p95 de traitement visible dans GCP.
- Le contrôle HEAD, les appels ordinaires du site et les autres visiteurs peuvent
  aussi apparaître dans Grafana. Les compteurs du panneau excluent le HEAD.

Ce sont 10 clients logiques dans un navigateur, pas 10 personnes ni 10 lecteurs vidéo.
La charge ne prouve pas un autoscaling sur plusieurs instances : elle peut être servie
par une seule instance. Le générateur et les tableaux Grafana affichent des résultats réels,
sans injecter de fausses métriques.

## Vérification locale et livraison

```sh
node --test catalogue/tests/load-runner.test.mjs
docker compose up --build
```

Ouvrir `http://localhost:8080`. Le lien Grafana exige le déploiement GCP et son accès
habituel ; Docker Compose du catalogue ne déploie pas ce dashboard à `/monitoring`.
Les tests automatisés utilisent de fausses réponses locales et une horloge accélérée :
aucun appel au site GCP. Pour publier le bouton, reconstruire et déployer l’image
du catalogue selon le processus du groupe ; une modification des fichiers seule
ne met pas à jour le service Cloud Run.

### Publication sur GCP

1. Construire l'image depuis `catalogue/` avec un tag inédit et la pousser dans
   `europe-west9-docker.pkg.dev/streambox-insset-m1-2026/streambox/catalogue`.
2. Reporter le digest publié dans `module.catalogue.image` de `terraform/main.tf`.
3. Pousser le code et cette référence sur `dev`, puis ouvrir une PR vers `main`.
4. Attendre les tests du générateur, les validations Terraform et examiner le plan
   GitHub Actions. Le changement prévu pour cette livraison est l'image du catalogue.
5. Fusionner la PR validée : le workflow « Terraform Apply & Smoke Test » déploie
   depuis `main`. Ne pas exécuter `terraform apply` localement.
6. Vérifier le bouton sur `https://streambox.chaleonm.ovh` après la réussite du workflow.

La construction de l'image est actuellement manuelle ; le déploiement Terraform
est automatisé par GitHub Actions. Grafana reste hébergé sur GCP.

Publication des métriques :
- https://docs.cloud.google.com/monitoring/api/metrics_gcp_p_z (Cloud Run)
- https://docs.cloud.google.com/load-balancing/docs/metrics (Load Balancer / CDN)
