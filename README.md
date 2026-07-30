# Practica CI/CD - Inventario App

Autor: Angel Patricio Lucero Loja

Repositorio: https://github.com/patrici0l/Practica-CI-CD

## Resumen

Esta practica toma una app Node.js de inventario y le agrega un flujo CI/CD:

- Pruebas automatizadas con `npm test`.
- Imagen Docker que solo se construye si las pruebas pasan.
- Pipeline en GitHub Actions.
- Escaneo de seguridad con Trivy.
- Publicacion de imagen en GHCR.
- Despliegue en Kubernetes con replicas y probes.
- Cambio de version con Blue-Green.

## Archivos clave

- `server.test.js`: pruebas automatizadas.
- `Dockerfile`: construye la imagen y ejecuta tests.
- `.github/workflows/ci-cd.yml`: pipeline CI/CD.
- `k8s/deployment.yaml`: despliegue base.
- `k8s/service.yaml`: expone la app.
- `k8s/blue-green/*`: despliegue Blue-Green.

## Pipeline

El pipeline tiene dos partes:

- `build-test`: instala dependencias y ejecuta `npm test`.
- `build-push`: construye, escanea con Trivy y publica en GHCR.

Comando para activar el pipeline:

```powershell
git add .
git commit -m "fix: completar practica ci cd"
git push origin main
```

Imagen publicada:

```text
ghcr.io/patrici0l/practica-ci-cd:latest
```

## Comandos importantes

Ejecutar tests:

```powershell
npm test
```

Construir imagen Docker:

```powershell
docker build --no-cache -t inventario-app:local .
```

Desplegar en Kubernetes:

```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/inventario-app
kubectl get pods -l app=inventario-app --show-labels
minikube service inventario-service --url
```

## Blue-Green

Crear Secret para Green:

```powershell
$env:API_KEY_VALUE = "api-" + [guid]::NewGuid().ToString()
kubectl create secret generic api-secret --from-literal=API_KEY="$env:API_KEY_VALUE" --dry-run=client -o yaml | kubectl apply -f -
Remove-Item Env:\API_KEY_VALUE
```

Desplegar Blue y Green:

```powershell
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service.yaml
kubectl rollout status deployment/inventario-app-blue
kubectl rollout status deployment/inventario-app-green
```

Probar version actual:

```powershell
minikube service inventario-service-bg --url
$bgUrl = "PEGAR_URL"
curl.exe "$bgUrl/version"
```

Cambiar trafico a Green:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
curl.exe "$bgUrl/version"
```

Regresar a Blue:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v1"}}}'
curl.exe "$bgUrl/version"
```

## Frase para explicar

La practica automatiza el paso de codigo a despliegue. Primero se prueban los cambios, luego Docker construye la imagen, GitHub Actions la escanea con Trivy y la publica en GHCR. Kubernetes despliega la app y Blue-Green permite mover el trafico entre `v1` y `v2` cambiando el selector del Service.
