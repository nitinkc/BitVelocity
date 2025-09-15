#!/usr/bin/env bash
set -e
echo "[*] Starting local infra (Postgres, Kafka (Redpanda), Redis)..."
docker compose -f scripts/dev/docker-compose.infra.yml up -d
echo "[*] Waiting for Postgres..."
sleep 5
echo "[*] Ready."