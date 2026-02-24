-- Create databases for all apps
-- Runs once on first Postgres startup

CREATE DATABASE nagz;
CREATE DATABASE obo;
CREATE DATABASE alities;

-- Create app-specific users (change passwords via fly secrets)
CREATE USER nagz_user WITH PASSWORD 'P$$Ba#';
GRANT ALL PRIVILEGES ON DATABASE nagz TO nagz_user;

CREATE USER obo_user WITH PASSWORD 'P$$Ba#';
GRANT ALL PRIVILEGES ON DATABASE obo TO obo_user;

CREATE USER alities_user WITH PASSWORD 'P$$Ba#';
GRANT ALL PRIVILEGES ON DATABASE alities TO alities_user;

CREATE DATABASE card_engine;
CREATE USER card_engine_user WITH PASSWORD 'P$$Ba#';
GRANT ALL PRIVILEGES ON DATABASE card_engine TO card_engine_user;
