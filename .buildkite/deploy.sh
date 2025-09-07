#!/bin/bash
set -euo pipefail

# Load environment variables if .env exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Configuration
: "${DOCKER_USERNAME:?DOCKER_USERNAME must be set}"
: "${DOCKER_PASSWORD:?DOCKER_PASSWORD must be set}"
: "${KUBE_CONFIG:?KUBE_CONFIG must be set}"

# Set Kubernetes context based on environment
if [ "$ENVIRONMENT" = "staging" ]; then
  KUBE_CONTEXT="staging"
  NAMESPACE="go-microservices-staging"
elif [ "$ENVIRONMENT" = "production" ]; then
  KUBE_CONTEXT="production"
  NAMESPACE="go-microservices-prod"
else
  echo "Unknown environment: $ENVIRONMENT"
  exit 1
fi

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy MySQL
kubectl apply -f ./mysql/deployment.yaml -n $NAMESPACE

# Build and push Docker images
echo "--- Building and pushing Docker images"
for service in order payment; do
  docker build -t your-docker-username/$service:${BUILDKITE_COMMIT:0:7} ./$service
  docker push your-docker-username/$service:${BUILDKITE_COMMIT:0:7}
  
  # Update image tag in deployment
  sed -i.bak "s|image: .*|image: your-docker-username/$service:${BUILDKITE_COMMIT:0:7}|" ./$service/deployment.yaml
  
  # Apply Kubernetes manifests
  kubectl apply -f ./$service/deployment.yaml -n $NAMESPACE
  
  # Verify deployment
  kubectl rollout status deployment/$service -n $NAMESPACE --timeout=60s
  
  # Restore original deployment file
  mv ./$service/deployment.yaml.bak ./$service/deployment.yaml
done

echo "--- Deployment to $ENVIRONMENT complete!"
