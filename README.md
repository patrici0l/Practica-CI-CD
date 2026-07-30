# Practica CI/CD - Inventario App

Aplicacion Node.js/Express usada para demostrar una practica de CI/CD con Docker, GitHub Actions, GHCR, Trivy y Kubernetes en Minikube.

Autor: Angel Patricio Lucero Loja

Repositorio: https://github.com/patrici0l/Practica-CI-CD

## Lo mas importante de la practica

El proyecto demuestra una cadena de entrega continua:

1. Se ejecutan pruebas automatizadas.
2. Docker construye la imagen solo si las pruebas pasan.
3. GitHub Actions repite el proceso en la nube.
4. Trivy escanea la imagen antes de publicarla.
5. Si todo esta correcto, la imagen se sube a GHCR.
6. Kubernetes despliega la imagen con replicas, probes y rolling update.
7. Blue-Green permite cambiar el trafico entre `v1` y `v2` modificando el selector del Service.

## Archivos principales

| Archivo | Funcion |
|---|---|
| `server.js` | Servidor Express. Expone `/health`, `/version` y `/api/products`. |
| `server.test.js` | Pruebas automatizadas de los endpoints principales. |
| `Dockerfile` | Imagen multi-stage. Primero corre tests y luego genera la imagen final. |
| `.github/workflows/ci-cd.yml` | Pipeline: test, build, Trivy y push a GHCR. |
| `k8s/deployment.yaml` | Deployment base con 2 replicas, rolling update y probes. |
| `k8s/service.yaml` | Service base para exponer la app en Minikube. |
| `k8s/blue-green/deployment-blue.yaml` | Version Blue (`v1`). |
| `k8s/blue-green/deployment-green.yaml` | Version Green (`v2`), usa Secret y readiness con arranque lento. |
| `k8s/blue-green/service.yaml` | Service que cambia el trafico entre Blue y Green. |

## Pruebas automatizadas

Las pruebas estan en `server.test.js` y se ejecutan con:

```powershell
npm test
```

Esto importa porque el pipeline y el `Dockerfile` dependen de esas pruebas. Si fallan, no se debe publicar la imagen.

## Docker

Construir la imagen:

```powershell
docker build --no-cache -t inventario-app:local .
```

El `Dockerfile` primero ejecuta `npm test`. Si las pruebas fallan, el build se detiene. Esta es una regla clave de CI/CD: no se empaqueta codigo roto.

## Pipeline CI/CD

El pipeline esta en:

```text
.github/workflows/ci-cd.yml
```

Tiene dos jobs principales:

| Job | Que hace |
|---|---|
| `build-test` | Instala dependencias y ejecuta `npm test`. |
| `build-push` | Construye imagen, escanea con Trivy y publica en GHCR. |

`build-push` usa `needs: build-test`, por eso solo corre si las pruebas pasaron.

Para activar el pipeline:

```powershell
git add .
git commit -m "fix: completar practica ci cd"
git push origin main
```

La imagen publicada queda en:

```text
ghcr.io/patrici0l/practica-ci-cd:latest
ghcr.io/patrici0l/practica-ci-cd:<hash-del-commit>
```

## Trivy

Trivy escanea la imagen antes de subirla:

```yaml
uses: aquasecurity/trivy-action@0.35.0
severity: CRITICAL
exit-code: '1'
```

Si encuentra una vulnerabilidad critica, el pipeline falla y no publica la imagen.

## Kubernetes base

Desplegar la app:

```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/inventario-app
kubectl get pods -l app=inventario-app --show-labels
kubectl get svc inventario-service
```

Obtener URL en Minikube:

```powershell
minikube service inventario-service --url
```

Probar con la URL:

```powershell
$url = "PEGAR_URL_DE_MINIKUBE"
curl.exe "$url/health"
curl.exe "$url/version"
curl.exe "$url/api/products"
```

Puntos para explicar:

- `Deployment` mantiene los pods funcionando.
- `replicas: 2` crea dos pods de la aplicacion.
- `Service` expone los pods aunque sus nombres cambien.
- `readinessProbe` evita enviar trafico a un pod que aun no esta listo.
- `livenessProbe` ayuda a reiniciar la app si deja de responder.

## Datos efimeros en pods

La app guarda productos en un JSON local dentro del pod. Si se borra un pod, Kubernetes crea otro, pero ese nuevo pod puede no tener los datos agregados antes.

Demostracion:

```powershell
kubectl get pods -l app=inventario-app
kubectl delete pod NOMBRE_DEL_POD
kubectl get pods -l app=inventario-app -w
```

Esto demuestra por que en produccion se necesita una base de datos externa o volumen persistente.

## Blue-Green

Blue-Green usa dos Deployments:

| Version | Deployment | Valor |
|---|---|---|
| Blue | `inventario-app-blue` | `APP_VERSION=v1` |
| Green | `inventario-app-green` | `APP_VERSION=v2` |

Primero se crea el Secret que usa Green:

```powershell
$env:API_KEY_VALUE = "api-" + [guid]::NewGuid().ToString()
kubectl create secret generic api-secret --from-literal=API_KEY="$env:API_KEY_VALUE" --dry-run=client -o yaml | kubectl apply -f -
Remove-Item Env:\API_KEY_VALUE
```

Aplicar Blue, Green y el Service:

```powershell
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service.yaml

kubectl rollout status deployment/inventario-app-blue
kubectl rollout status deployment/inventario-app-green
kubectl get pods -l app=inventario-app --show-labels
```

Obtener URL:

```powershell
minikube service inventario-service-bg --url
```

Ver version actual:

```powershell
$bgUrl = "PEGAR_URL_DE_MINIKUBE_BG"
curl.exe "$bgUrl/version"
```

Cambiar trafico a Green:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
curl.exe "$bgUrl/version"
```

Regresar trafico a Blue:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v1"}}}'
curl.exe "$bgUrl/version"
```

Lo importante: no se cambia el codigo ni se reconstruye la imagen para mover el trafico. Solo se cambia el selector del Service.

## Readiness en Green

Green tiene `STARTUP_DELAY_SECONDS=20`. Durante ese tiempo `/health` responde temporalmente mal y Kubernetes no envia trafico hasta que el pod este listo.

```powershell
kubectl rollout restart deployment/inventario-app-green
kubectl get pods -l app=inventario-app,version=v2 -w
```

Ver detalles:

```powershell
$pod = kubectl get pods -l app=inventario-app,version=v2 -o jsonpath='{.items[0].metadata.name}'
kubectl describe pod $pod
```

## Comandos clave para exponer

```powershell
npm test

docker build --no-cache -t inventario-app:local .

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/inventario-app
kubectl get pods -l app=inventario-app --show-labels
minikube service inventario-service --url

$env:API_KEY_VALUE = "api-" + [guid]::NewGuid().ToString()
kubectl create secret generic api-secret --from-literal=API_KEY="$env:API_KEY_VALUE" --dry-run=client -o yaml | kubectl apply -f -
Remove-Item Env:\API_KEY_VALUE

kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service.yaml
kubectl rollout status deployment/inventario-app-blue
kubectl rollout status deployment/inventario-app-green
minikube service inventario-service-bg --url

$bgUrl = "PEGAR_URL_DE_MINIKUBE_BG"
curl.exe "$bgUrl/version"
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
curl.exe "$bgUrl/version"
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v1"}}}'
curl.exe "$bgUrl/version"
```

## Explicacion corta

La practica convierte una aplicacion simple de inventario en un flujo CI/CD. Primero se agregaron pruebas. Luego Docker valida esas pruebas antes de construir la imagen. GitHub Actions automatiza el proceso, Trivy revisa vulnerabilidades y GHCR almacena la imagen. Finalmente Kubernetes despliega la aplicacion con replicas y probes, y Blue-Green permite cambiar el trafico entre dos versiones usando el selector del Service.
