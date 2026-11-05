# Arma la red vial de pgRouting desde OpenStreetMap (ver cargar.sh y red_vial_osm.py).
FROM python:3.12-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client curl libexpat1 \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir osmium numpy
COPY red_vial_osm.py cargar.sh /app/
ENTRYPOINT ["/bin/sh", "/app/cargar.sh"]
