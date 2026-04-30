# DEMO 3 - External Secrets Operator + Vault

A demo célja: élőben mutatni, hogy egy Vault-beli titok módosítása **automatikusan** átkerül a klaszterbe lévő pod-hoz, **restart nélkül**.

## Gyors setup

Abban az esetben, ha nem szeretnénk manuálisan végrehajtani a lenti lépéseket, használhatjuk a `setup.sh` scriptet, amely automatikusan létrehozza a klasztert, telepíti a szükséges komponenseket, és beállítja a Vault-ot.

## Manuális setup lépések

### 1. Klaszter létrehozása

```bash
kind delete cluster --name external-secrets-demo 2>/dev/null || true
kind create cluster --name external-secrets-demo
```

### 2. Helm repo-k

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
helm repo add external-secrets https://charts.external-secrets.io 2>/dev/null || true
helm repo update
```

### 3. Vault telepítése (dev mód)

```bash
helm install vault hashicorp/vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root" \
  --set "injector.enabled=false"

kubectl wait --for=condition=Ready pod/vault-0 --timeout=180s
```

### 4. Vault konfigurálása

#### Belépés a Vault podba

```bash
kubectl exec -it vault-0 -- /bin/sh
```

#### Kubernetes auth + policy + role + titok

```sh
export VAULT_TOKEN=root

vault auth enable kubernetes

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
```

#### Titok létrehozása a Vault-ban

```bash
vault kv put secret/demo-app \
  db-username="admin" \
  db-password="SuperSecret123!" \
  api-token="tok_abc12345xyz"

exit
```

### 5. ESO telepítése

```bash
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace

kubectl wait --for=condition=Ready pods --all \
  -n external-secrets --timeout=180s
```

### 6. Manifest-ek alkalmazása

```bash
kubectl apply -f manifests/

kubectl get externalsecret demo-app-secret
kubectl get secret demo-app-credentials
```

### 7. Demo app log-ok figyelése

**1. terminál:**

```bash
kubectl logs -l app=demo-app -f
```

### 8. Titok módosítása CLI-ből

**2. terminál:**

```bash
kubectl exec -it vault-0 -- env VAULT_TOKEN=root vault kv put secret/demo-app \
  db-username="admin" \
  db-password="BRAND_NEW_PASSWORD_2026" \
  api-token="tok_xyz98765abc"
```

~15 mp múlva a log-ban megjelenik az új jelszó. **A pod nem indult újra!**

### 9. Vault UI demonstráció

```bash
kubectl port-forward svc/vault 8200:8200 &
```

Böngészőben: `http://localhost:8200` (token: `root`)

A UI-ról is módosítható a titok - a klaszter ugyanúgy szinkronizál.

### 10. REST API demonstráció

```bash
curl --header "X-Vault-Token: root" \
     --request GET \
     http://127.0.0.1:8200/v1/secret/data/demo-app >> demo-app-secret.json
```

### 11. Takarítás

```bash
./teardown.sh
# vagy:
kind delete cluster --name external-secrets-demo
```

---

## Segédletek

### Listázás

```bash
kind get clusters
kubectl get pods
kubectl get pods -n external-secrets
```

### Ellenőrzés a Vault-ban

```bash
vault auth list
vault policy list
vault read auth/kubernetes/role/demo-app
```
