# Expo clase - CI/CD

Guia corta para mostrar solo lo importante.

## 1. Que se hizo

- Se agregaron pruebas en `server.test.js`.
- Se creo un `Dockerfile` que corre tests antes de construir.
- Se creo un pipeline en `.github/workflows/ci-cd.yml`.
- El pipeline prueba, construye, escanea con Trivy y publica en GHCR.
- Se agrego Kubernetes base con `Deployment` y `Service`.
- Se agrego Blue-Green con version `v1` y `v2`.

## 2. Comandos para exponer

Entrar al proyecto:

```powershell
cd "C:\A_PROJECTS\PRACTICA CI-CD\inventario-app"
```

Probar:

```powershell
npm test
```

Construir Docker:

```powershell
docker build --no-cache -t inventario-app:local .
```

Desplegar base:

```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/inventario-app
kubectl get pods -l app=inventario-app --show-labels
minikube service inventario-service --url
```

Crear Secret:

```powershell
$env:API_KEY_VALUE = "api-" + [guid]::NewGuid().ToString()
kubectl create secret generic api-secret --from-literal=API_KEY="$env:API_KEY_VALUE" --dry-run=client -o yaml | kubectl apply -f -
Remove-Item Env:\API_KEY_VALUE
```

Desplegar Blue-Green:

```powershell
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service.yaml
kubectl rollout status deployment/inventario-app-blue
kubectl rollout status deployment/inventario-app-green
```

Probar version:

```powershell
minikube service inventario-service-bg --url
$bgUrl = "PEGAR_URL"
curl.exe "$bgUrl/version"
```

Cambiar a Green:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
curl.exe "$bgUrl/version"
```

Volver a Blue:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v1"}}}'
curl.exe "$bgUrl/version"
```

## 3. Que decir

La app pasa por un flujo CI/CD: primero se prueban los cambios, luego Docker construye la imagen, GitHub Actions automatiza el proceso, Trivy escanea seguridad y GHCR guarda la imagen. En Kubernetes se despliega con replicas y Blue-Green permite mover trafico de `v1` a `v2` cambiando el selector del Service.
