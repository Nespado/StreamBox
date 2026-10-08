#!/bin/sh
set -eu

# Aucune valeur secrète ni URL publique n'est fixée dans l'image.
: "${PROMETHEUS_URL:?Fournir l'URL du proxy authentifie vers Managed Service for Prometheus}"
: "${GF_SERVER_ROOT_URL:?Fournir l'URL publique complete, avec /monitoring/}"
if [ -z "${GF_SECURITY_ADMIN_PASSWORD:-}" ] && [ -z "${GF_SECURITY_ADMIN_PASSWORD__FILE:-}" ]; then
    echo >&2 'Fournir GF_SECURITY_ADMIN_PASSWORD ou GF_SECURITY_ADMIN_PASSWORD__FILE via Secret Manager.'
    exit 1
fi

# Cloud Run fournit PORT. Le port par défaut permet aussi de tester l'image.
export GF_SERVER_HTTP_PORT="${PORT:-8080}"
exec /run.sh "$@"
