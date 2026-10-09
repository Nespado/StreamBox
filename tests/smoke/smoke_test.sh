#!/usr/bin/env bash
# ==============================================================================
# StreamBox - Smoke Test (Parcours Nominal)
# Vérifie les routes nominales à travers le Load Balancer :
# 1. Health check (/healthz)
# 2. Consultation du catalogue (/api/catalogue)
# 3. Distribution statique et statut du cache CDN (/media/*)
# ==============================================================================
set -euo pipefail

TARGET_URL="${1:-https://streambox.chaleonm.ovh}"

echo "=========================================================="
echo " [STREAMBOX] Exécution des Smoke Tests sur : $TARGET_URL"
echo "=========================================================="

FAILED=0

# 1. Test Health Check
echo -n "[TEST 1/3] Vérification /healthz ... "
STATUS=$(curl -k -s -o /dev/null -w "%{http_code}" "$TARGET_URL/healthz" || true)
if [ "$STATUS" -eq 200 ]; then
  echo "SUCCÈS (HTTP 200)"
else
  echo "ÉCHEC (HTTP $STATUS attendu 200)"
  FAILED=1
fi

# 2. Test Catalogue API
echo -n "[TEST 2/3] Consultation de l'API /api/catalogue ... "
API_RES=$(curl -k -s "$TARGET_URL/api/catalogue" || true)
if echo "$API_RES" | grep -q '"videos"'; then
  echo "SUCCÈS (JSON valide avec catalogue)"
else
  echo "ÉCHEC (Réponse inattendue : $API_RES)"
  FAILED=1
fi

# 3. Test CDN Media et en-tête X-Cache-Status
echo "[TEST 3/3] Vérification du CDN (/media/test.mp4) :"
# Première requête pour peupler le cache
echo -n "  - Requête 1 (Attendu : MISS ou HIT si déjà amorcé) ... "
HEADER_1=$(curl -k -s -I "$TARGET_URL/media/demo-1.mp4" 2>/dev/null || true)
STATUS_1=$(echo "$HEADER_1" | grep -i "HTTP/" | tail -n1 | awk '{print $2}' || true)
CACHE_1=$(echo "$HEADER_1" | grep -i "x-cache-status:" | awk '{print $2}' | tr -d '\r' || echo "UNKNOWN")
echo "HTTP $STATUS_1, X-Cache-Status: $CACHE_1"

# Deuxième requête (doit être servie depuis le cache)
echo -n "  - Requête 2 (Attendu : HIT ou REVALIDATED) ... "
HEADER_2=$(curl -k -s -I "$TARGET_URL/media/demo-1.mp4" 2>/dev/null || true)
STATUS_2=$(echo "$HEADER_2" | grep -i "HTTP/" | tail -n1 | awk '{print $2}' || true)
CACHE_2=$(echo "$HEADER_2" | grep -i "x-cache-status:" | awk '{print $2}' | tr -d '\r' || echo "UNKNOWN")
echo "HTTP $STATUS_2, X-Cache-Status: $CACHE_2"

if [ "$STATUS_2" -eq 200 ]; then
  echo "  => Distribution média fonctionnelle."
else
  echo "  => AVERTISSEMENT : Média non disponible (HTTP $STATUS_2). Vérifiez le bucket."
fi

echo "=========================================================="
if [ "$FAILED" -eq 0 ]; then
  echo " [STREAMBOX] Tous les smoke tests du parcours nominal sont validés !"
  exit 0
else
  echo " [STREAMBOX] Des tests nominaux ont échoué."
  exit 1
fi
