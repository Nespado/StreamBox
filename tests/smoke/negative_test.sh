#!/usr/bin/env bash
# ==============================================================================
# StreamBox - Tests Négatifs (Erreurs et Refus Attendus)
# Valide la sécurité et le comportement des limites du système :
# 1. Refus de contournement du Load Balancer (Accès direct Cloud Run URL -> HTTP 403)
# 2. Rejet des méthodes HTTP interdites (POST sur /api/catalogue -> HTTP 405)
# 3. Gestion des ressources inexistantes (/api/catalogue/inconnu -> HTTP 404)
# ==============================================================================
set -euo pipefail

TARGET_URL="${1:-https://streambox.chaleonm.ovh}"
# Optionnel : URL directe Cloud Run fournie en argument 2
DIRECT_CLOUD_RUN_URL="${2:-}"

echo "=========================================================="
echo " [STREAMBOX] Exécution des Tests Négatifs"
echo "=========================================================="

FAILED=0

# 1. Test Méthode non autorisée (POST non supporté)
echo -n "[TEST NEGATIF 1/3] POST sur route en lecture seule (/api/catalogue) ... "
STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST "$TARGET_URL/api/catalogue" || true)
if [ "$STATUS" -eq 405 ]; then
  echo "SUCCÈS (HTTP 405 Method Not Allowed obtenu comme attendu)"
else
  echo "ÉCHEC (HTTP $STATUS obtenu au lieu de 405)"
  FAILED=1
fi

# 2. Test Ressource introuvable
echo -n "[TEST NEGATIF 2/3] GET sur une vidéo inexistante (/api/catalogue/non-existent-id) ... "
STATUS_404=$(curl -k -s -o /dev/null -w "%{http_code}" "$TARGET_URL/api/catalogue/non-existent-id" || true)
if [ "$STATUS_404" -eq 404 ]; then
  echo "SUCCÈS (HTTP 404 Not Found obtenu comme attendu)"
else
  echo "ÉCHEC (HTTP $STATUS_404 obtenu au lieu de 404)"
  FAILED=1
fi

# 3. Test Isolement Ingress Cloud Run (accès direct interdit)
echo -n "[TEST NEGATIF 3/3] Accès direct sans passer par le Load Balancer ... "
if [ -n "$DIRECT_CLOUD_RUN_URL" ]; then
  DIRECT_STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "$DIRECT_CLOUD_RUN_URL" || true)
  if [ "$DIRECT_STATUS" -eq 403 ]; then
    echo "SUCCÈS (HTTP 403 Forbidden : Ingress filtré par Google Front End)"
  else
    echo "ÉCHEC (HTTP $DIRECT_STATUS au lieu de 403 sur $DIRECT_CLOUD_RUN_URL)"
    FAILED=1
  fi
else
  echo "IGNORE (Fournir l'URL run.app en paramètre pour tester le 403)"
fi

echo "=========================================================="
if [ "$FAILED" -eq 0 ]; then
  echo " [STREAMBOX] Tous les tests négatifs sont conformes aux attentes !"
  exit 0
else
  echo " [STREAMBOX] Un ou plusieurs tests négatifs ont échoué."
  exit 1
fi
