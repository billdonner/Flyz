FROM postgres:16-alpine

# Create multiple databases on first init
COPY init/ /docker-entrypoint-initdb.d/

ENV POSTGRES_PASSWORD=changeme
ENV PGDATA=/var/lib/postgresql/data/pgdata

EXPOSE 5432
