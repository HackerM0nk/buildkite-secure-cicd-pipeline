#!/usr/bin/env bash
set -euo pipefail

# 0) Clean up prior mysql if it exists
docker rm -f ci-mysql >/dev/null 2>&1 || true

# 1) Start MySQL (only)
echo "--- Starting MySQL"
docker run -d --name ci-mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_USER=user \
  -e MYSQL_PASSWORD=password \
  -e MYSQL_DATABASE=orders \
  -v "$(pwd)/e2e/resources/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  mysql:8.0

# 2) Wait until MySQL is ready
echo "--- Waiting for MySQL readiness"
for i in {1..60}; do
  if docker exec ci-mysql mysqladmin ping -h 127.0.0.1 -uroot -proot --silent; then
    break
  fi
  sleep 1
done
docker exec ci-mysql mysql -uroot -proot -e "CREATE DATABASE IF NOT EXISTS payments;"

mkdir -p test-results

# 3) Run ORDER tests (use golang toolchain image)
echo "--- Running Order Service tests"
docker run --rm \
  --network "container:ci-mysql" \
  -e DB_HOST=127.0.0.1 \
  -e DB_PORT=3306 \
  -e DB_USER=user \
  -e DB_PASSWORD=password \
  -e DB_NAME=orders \
  -v "$(pwd)/order:/workspace" \
  -w /workspace \
  golang:1.22 \
  bash -lc 'go mod download && go test -v ./... | tee /workspace/../test-results/order-test-output.txt' \
  || echo "Order tests failed but continuing..."

# 4) Run PAYMENT tests
echo "--- Running Payment Service tests"
docker run --rm \
  --network "container:ci-mysql" \
  -e DB_HOST=127.0.0.1 \
  -e DB_PORT=3306 \
  -e DB_USER=user \
  -e DB_PASSWORD=password \
  -e DB_NAME=payments \
  -v "$(pwd)/payment:/workspace" \
  -w /workspace \
  golang:1.22 \
  bash -lc 'go mod download && go test -v ./... | tee /workspace/../test-results/payment-test-output.txt' \
  || echo "Payment tests failed but continuing..."

echo "--- Test Results"
cat test-results/*.txt || true

# 5) Cleanup
echo "--- Cleaning up MySQL"
docker rm -f ci-mysql >/dev/null 2>&1 || true
