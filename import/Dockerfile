FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    osm2pgrouting \
    postgresql-client \
    osmctools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY entrypoint.sh .
COPY init.sql .

RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]

