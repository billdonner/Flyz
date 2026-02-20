FROM node:20-slim AS frontend

WORKDIR /web
COPY nagz-web/package.json nagz-web/package-lock.json ./
RUN npm ci
COPY nagz-web/ .
ENV VITE_API_URL=""
RUN npm run build

FROM python:3.12-slim

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY . .
RUN rm -rf nagz-web
RUN uv pip install --system --no-cache .

COPY --from=frontend /web/dist /app/static-web

EXPOSE 8080

CMD ["uvicorn", "nagz.server.main:app", "--host", "0.0.0.0", "--port", "8080"]
