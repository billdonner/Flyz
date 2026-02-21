FROM python:3.12-slim

WORKDIR /app

# Install uv for fast dependency resolution
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency spec first for layer caching
COPY pyproject.toml .
RUN uv pip install --system --no-cache -r pyproject.toml

# Install anthropic for advice app
RUN uv pip install --system --no-cache "anthropic>=0.36,<1"

# Copy application code
COPY web.py .
COPY collectors/ collectors/
COPY static/ static/

# Copy advice app (co-hosted sub-application)
COPY advice_app/ advice_app/

# Copy Fly-specific config (overrides local servers.yaml)
COPY fly-config/servers.yaml config/servers.yaml

EXPOSE 8080

CMD ["python", "web.py", "--host", "0.0.0.0", "--port", "8080", "-c", "config/servers.yaml"]
