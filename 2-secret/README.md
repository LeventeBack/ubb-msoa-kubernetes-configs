# Secret — Demó

Ez a demó bemutatja, hogyan működnek a Kubernetes **Secret**-ek: hogyan hozunk létre egyet manuálisan, hogyan kerül be a pod-ba környezeti változóként, és hogyan olvassa azt az alkalmazás futásidőben.

> **Technológiák:** Docker Desktop (Kubernetes engedélyezve), `kubectl`, egyszerű Flask alkalmazás.

---

## Előfeltételek

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) telepítve és futó állapotban
- Kubernetes engedélyezve a Docker Desktop-ban (*Settings → Kubernetes → Enable Kubernetes*)
- `kubectl` elérhető a terminálon (Docker Desktop-pal együtt települ)

---

## Reprodukálás lépései

### 1. Docker Desktop context beállítása

Győződj meg róla, hogy a `kubectl` a helyi Docker Desktop klaszterrel kommunikál:

```powershell
kubectl config use-context docker-desktop
```

Ellenőrzés:

```powershell
kubectl cluster-info
```

---

### 2. Docker image buildelése

A `2-secret/` mappából buildeld meg a Flask alkalmazás image-ét.  
A tag-nek **egyeznie kell** azzal, amit az `app-setup.yaml` hivatkozik (`my-flask-app`):

```powershell
docker build -t my-flask-app .
```

> Az `imagePullPolicy: Never` be van állítva a manifestben, így Kubernetes a lokálisan épített image-et használja, registry-ből nem próbálja letölteni.

---

### 3. A Secret manuális létrehozása

Az alkalmazás egy **`db-pass`** nevű Secret-et vár, amelynek **`SECRET_DATA`** kulcsa van.  
Hozzuk létre `kubectl`-lel — az érték semmilyen fájlba nem kerül be:

```powershell
kubectl create secret generic db-pass `
  --from-literal=SECRET_DATA=K8sSecret2026
```

Ellenőrzés:

```powershell
kubectl get secret db-pass
```

A nyers (base64-kódolt) értéket így lehet megnézni — ezzel is szemléltethetjük, hogy a Kubernetes csak kódolt formában tárolja:

```powershell
kubectl get secret db-pass -o yaml
```

A dekódolás PowerShell-ből, hogy megmutassuk: a base64 **nem** titkosítás:

```powershell
[System.Text.Encoding]::UTF8.GetString(
  [System.Convert]::FromBase64String("SzhzU2VjcmV0MjAyNg==")
)
# Eredmény: K8sSecret2026
```

---

### 4. Az alkalmazás telepítése

Alkalmazzuk a manifestet (ConfigMap + Deployment + Service):

```powershell
kubectl apply -f app-setup.yaml
```

Várjuk meg, amíg a pod elindul:

```powershell
kubectl get pods -w
```

Ha a pod státusza `Running`, kiléphetünk a `Ctrl+C`-vel.

---

### 5. Az alkalmazás elérése

A Service **NodePort 30001**-en van kiszolgálva. Nyisd meg böngészőben:

```
http://localhost:30001
```

Egy bejelentkezési form jelenik meg.

---

### 6. A Secret működésének bemutatása

Írjuk be a jelszót: **`K8sSecret2026`**, majd küldjük el.  
Az alkalmazás a `SECRET_DATA` környezeti változóból olvassa az értéket (amelyet a Secret injektál), és összehasonlítja a bevittel.

- **Helyes jelszó** → „Sikeres belépés!"
- **Helytelen jelszó** → „Hiba!"

Ez megerősíti, hogy a pod sikeresen olvassa a Kubernetes Secret értékét futásidőben.

---

### 7. Mi történik Secret nélkül?

Töröljük a Secret-et, és indítsuk újra a pod-ot:

```powershell
kubectl delete secret db-pass
kubectl rollout restart deployment demo-app
```

A pod nem fog elindulni (`CreateContainerConfigError`), mert a szükséges Secret hiányzik.  
A hiba részletei:

```powershell
kubectl describe pod <pod-neve>
```

A Secret újralétrehozásával helyreállítható:

```powershell
kubectl create secret generic db-pass `
  --from-literal=SECRET_DATA=K8sSecret2026
kubectl rollout restart deployment demo-app
```

---

## Takarítás

Az összes létrehozott erőforrás törlése:

```powershell
kubectl delete -f app-setup.yaml
kubectl delete secret db-pass
```

---

## Hogyan működik? (rövid összefoglaló)

| Mi | Részlet |
|---|---|
| Secret tárolása | **etcd**-ben tárolódik, base64-kódolva (alapból nem titkosítva) |
| Pod-ba injektálás | **Környezeti változóként** kerül be `secretKeyRef` segítségével |
| Fájlrendszer | Az érték **tmpfs**-en (memóriában) él, nem a konténer lemezén |
| Hozzáférés-vezérlés | `kubectl get secret` RBAC jog szükséges az olvasáshoz |

> **Fő tanulság:** a `base64 ≠ titkosítás`. Aki rendelkezik a megfelelő RBAC jogosultsággal, triviálisan dekódolhatja az értéket. Éles környezethez lásd a `3-external-vault` demót.
