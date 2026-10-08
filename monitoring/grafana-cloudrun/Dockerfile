# Image officielle, version et contenu fixes pour des builds reproductibles.
FROM grafana/grafana:13.2.3@sha256:b28bae15e219c998fb0e0424ed724930cc61b1f61fb404d47c862f9a23f9e572

ENV GF_AUTH_ANONYMOUS_ENABLED=false \
    GF_USERS_ALLOW_SIGN_UP=false \
    GF_ANALYTICS_REPORTING_ENABLED=false \
    GF_ANALYTICS_CHECK_FOR_UPDATES=false \
    GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES=false \
    GF_SERVER_HTTP_ADDR=0.0.0.0 \
    GF_SERVER_SERVE_FROM_SUB_PATH=true \
    GF_LOG_MODE=console \
    GF_UNIFIED_ALERTING_ENABLED=false

# Les fichiers provisionnés sont séparés de la base SQLite éphémère.
COPY --chown=472:0 provisioning/ /etc/grafana/provisioning/
COPY --chown=472:0 dashboards/ /etc/grafana/dashboards/
COPY --chmod=755 entrypoint.sh /streambox-entrypoint.sh

USER 472
EXPOSE 8080
ENTRYPOINT ["/streambox-entrypoint.sh"]
