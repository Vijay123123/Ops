#!/usr/bin/env bash
# Run the same scans locally with Docker (no installs needed).
set -e
mkdir -p reports
echo "== Gitleaks =="
docker run --rm -v "$PWD:/repo" ghcr.io/gitleaks/gitleaks:v8.21.2 \
  detect --source /repo --config /repo/.gitleaks.toml --redact -v || true
echo "== Trivy (filesystem) =="
docker run --rm -v "$PWD:/src" aquasec/trivy:latest fs --severity CRITICAL,HIGH --scanners vuln /src || true
echo "== Trivy (image) =="
docker build -t guardrail-app:local .
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest \
  image --severity CRITICAL,HIGH --ignore-unfixed guardrail-app:local || true
