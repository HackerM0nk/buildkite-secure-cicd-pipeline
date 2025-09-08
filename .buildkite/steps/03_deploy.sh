set -euo pipefail
export ORDER_IMAGE="hackermonk/order:${TAG}"
export PAYMENT_IMAGE="hackermonk/payment:${TAG}"
VARS='${ORDER_IMAGE} ${PAYMENT_IMAGE}'

echo "--- Namespaces"
kubectl apply -f kubernetes/namespaces.yaml

echo "--- MySQL"
envsubst "$VARS" < kubernetes/mysql-deployment.yaml | kubectl apply --dry-run=client -f -
envsubst "$VARS" < kubernetes/mysql-deployment.yaml | kubectl apply -f -

echo "--- Services"
kubectl apply -f kubernetes/services.yaml

echo "--- Deployments"
for m in order-deployment.yaml payment-deployment.yaml; do
  echo "Applying $m"
  envsubst "$VARS" < "kubernetes/$m" | kubectl apply --dry-run=client -f -
  envsubst "$VARS" < "kubernetes/$m" | kubectl apply -f -
done
