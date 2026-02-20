# TODO: Fill in once alities-engine is ready to deploy
# Alities Engine is a Swift daemon — needs Swift runtime
FROM swift:5.9-jammy as builder

WORKDIR /app
COPY . .
RUN swift build -c release

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libcurl4 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/.build/release/AlitiesEngine /usr/local/bin/

EXPOSE 8080

CMD ["AlitiesEngine", "run", "--port", "8080"]
