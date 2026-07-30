# Practica CI/CD - Inventario App

Autor: Angel Patricio Lucero Loja

Repositorio: https://github.com/patrici0l/Practica-CI-CD

## Que se presenta

El proyecto ya esta creado. En la exposicion solo se muestra lo mas importante:

- Tests automatizados.
- Dockerfile con pruebas antes de construir.
- Pipeline de GitHub Actions.
- Escaneo con Trivy.
- Imagen publicada en GHCR.
- Kubernetes con pods y services.
- Cambio Blue-Green de `v1` a `v2`.

## Archivos importantes

- `server.test.js`: pruebas.
- `Dockerfile`: build de imagen y tests.
- `.github/workflows/ci-cd.yml`: pipeline.
- `k8s/deployment.yaml`: despliegue base.
- `k8s/service.yaml`: servicio base.
- `k8s/blue-green/*`: Blue-Green.

## Comandos principales para mostrar

Tests:

```powershell
npm test
```

Docker:

```powershell
Get-Content Dockerfile
docker build --no-cache -t inventario-app:local .
```

Pipeline:

```powershell
Get-Content .github\workflows\ci-cd.yml
```

Kubernetes:

```powershell
kubectl get pods -l app=inventario-app --show-labels
kubectl get svc
```

App base:

```powershell
minikube service inventario-service --url
$url = "PEGAR_URL"
curl.exe "$url/health"
curl.exe "$url/version"
```

Blue-Green:

```powershell
minikube service inventario-service-bg --url
$bgUrl = "PEGAR_URL_BG"
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

## Explicacion corta

Docker asegura que la imagen solo se construya si las pruebas pasan. GitHub Actions automatiza test, build, escaneo con Trivy y publicacion en GHCR. Kubernetes mantiene la app corriendo con pods y services. Blue-Green permite cambiar el trafico entre `v1` y `v2` modificando el selector del Service.
