#!/bin/bash
set -e

CLUSTER_NAME="external-secrets-demo"

echo "==> 1. Klaszter létrehozása"
kind delete cluster --name $CLUSTER_NAME 2>/dev/null || true
kind create cluster --name $CLUSTER_NAME

echo "==> 2. Helm repo-k frissítése"
helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update

echo "==> 3. Vault telepítése"
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root" \
  --set "injector.enabled=false"

echo "==> 3.1. Várakozás, amíg vault-0 létrejön..."
until kubectl get pod vault-0 >/dev/null 2>&1; do
  sleep 2
done

echo "==> 3.2. Várakozás, amíg vault-0 ready..."
kubectl wait --for=condition=Ready pod/vault-0 --timeout=180s

echo "==> 4. Vault konfigurálás (titok + auth)"
kubectl exec vault-0 -- /bin/sh -c '
export VAULT_TOKEN=root
vault kv put secret/demo-app \
  db-username="admin" \
  db-password="SuperSecret123!" \
  api-token="tok_abc12345xyz"

vault auth enable kubernetes || true

vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

vault policy write demo-app-policy - <<POL
path "secret/data/demo-app" {
  capabilities = ["read"]
}
POL

vault write auth/kubernetes/role/demo-app \
  bound_service_account_names=eso-vault-sa \
  bound_service_account_namespaces=default \
  policies=demo-app-policy \
  ttl=1h
'

echo "==> 5. ESO telepítése"
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace

echo "==> 5.1. Várakozás, amíg az ESO podok létrejönnek..."
until [ "$(kubectl get pods -n external-secrets --no-headers 2>/dev/null | wc -l)" -ge 3 ]; do
  sleep 2
done

echo "==> 5.2. Várakozás, amíg az ESO podok ready-k..."
kubectl wait --for=condition=Ready pods --all \
  -n external-secrets --timeout=180s

echo "==> 6. Manifest-ek alkalmazása"
kubectl apply -f manifests/

# Várjuk meg, hogy az ExternalSecret szinkronizálódjon
sleep 5

echo ""
echo "==> KÉSZ!"
echo ""
echo "Ellenőrzés:"
echo "  kubectl get externalsecret demo-app-secret"
echo "  kubectl get secret demo-app-credentials"
echo "  kubectl logs -l app=demo-app -f"
echo ""
echo "Vault UI:"
echo "  kubectl port-forward svc/vault 8200:8200"
echo "  Nyisd: http://localhost:8200 (token: root)"