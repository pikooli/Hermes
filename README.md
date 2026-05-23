# Hermes

Configuration project for editing and running a Hermes Agent AI server setup.

This repository builds a Hermes image based on `nousresearch/hermes-agent:latest`, adds Chromium for browser-based workflows, and starts the Hermes gateway with Docker Compose.

## Requirements

- Docker
- Docker Compose
- An API key set in the `API_SERVER_KEY` environment variable

## Configuration

The Hermes service is configured in `docker-compose.yml`.

Exposed ports:

- `8642` : API server Hermes
- `9119` : dashboard Hermes

Data volume:

- `/home/pikl/.hermes:/opt/data`

Main environment variables:

- `API_SERVER_ENABLED=true`
- `API_SERVER_HOST=0.0.0.0`
- `API_SERVER_PORT=8642`
- `API_SERVER_KEY=${API_SERVER_KEY}`
- `HERMES_DASHBOARD=1`
- `CHROME_BIN=/usr/bin/chromium`

## Run

Set the API key, then start the server:

```bash
export API_SERVER_KEY="change-me"
docker compose up --build
```

To run in the background:

```bash
docker compose up -d --build
```

## Access

Once the service is running:

- API Hermes : `http://localhost:8642`
- Dashboard Hermes : `http://localhost:9119`

## Stop

```bash
docker compose down
```
