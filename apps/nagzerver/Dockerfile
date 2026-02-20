# TODO: Fill in once nagzerver is ready to deploy
# Nagzerver is a Python/uvicorn API server
FROM python:3.12-slim

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml .
RUN uv pip install --system --no-cache -r pyproject.toml

COPY . .

EXPOSE 8080

CMD ["uvicorn", "nagz.server.main:app", "--host", "0.0.0.0", "--port", "8080"]
