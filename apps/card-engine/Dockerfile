FROM node:22-slim AS studio-build

WORKDIR /studio
COPY cardz-studio/package.json cardz-studio/package-lock.json ./
RUN npm ci
COPY cardz-studio/ .
ENV VITE_API_URL=""
RUN npx vite build --base /studio/

FROM python:3.12-slim

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml .
RUN uv pip install --system --no-cache -r pyproject.toml

COPY . .
RUN rm -rf cardz-studio

COPY --from=studio-build /studio/dist /app/studio-web

EXPOSE 8080

CMD ["uvicorn", "server.app:app", "--host", "0.0.0.0", "--port", "8080"]
