# inventario-app con CI/CD

Aplicacion Node.js/Express para practicar Docker, GitHub Actions, GHCR y despliegues en Kubernetes con Minikube. La base de datos es un archivo JSON local dentro del contenedor, por lo que los datos creados en un pod pueden perderse al recrearlo.

Repositorio publico: https://github.com/patrici0l/Practica-CI-CD

## 1. Ejecucion local

```powershell
npm ci
npm test
npm start
```

Abrir: http://localhost:3000

## 2. Docker local

El `Dockerfile` es multi-stage. La etapa `test` instala dependencias y ejecuta `npm test`; la imagen final copia el codigo desde esa etapa, asi que el build falla si las pruebas fallan.

```powershell
docker build --no-cache -t inventario-app:local .
docker run -d -p 3000:3000 --name mi-inventario inventario-app:local

curl.exe http://localhost:3000/
curl.exe http://localhost:3000/health
curl.exe http://localhost:3000/version
curl.exe http://localhost:3000/api/products

docker rm -f mi-inventario
```

## 3. CI/CD y GHCR

El workflow `.github/workflows/ci-cd.yml` tiene dos jobs encadenados:

- `build-test`: ejecuta `npm ci` y `npm test`.
- `build-push`: solo corre si `build-test` fue exitoso; construye la imagen, la escanea con Trivy y luego publica en GHCR con dos tags: hash completo del commit y `latest`.

```powershell
git add .
git commit -m "fix: completar requisitos de ci cd"
git push origin main
```

Verificar:

```powershell
$repo = "patrici0l/Practica-CI-CD"
Invoke-RestMethod -Headers @{"User-Agent"="curl"} "https://api.github.com/repos/$repo/actions/runs?per_page=5" |
  Select-Object -ExpandProperty workflow_runs |
  Select-Object head_sha,status,conclusion,created_at,updated_at,html_url
```

Paquete publicado: https://github.com/patrici0l/Practica-CI-CD/pkgs/container/practica-ci-cd

## 4. Rolling update base en Minikube

```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/inventario-app
kubectl get pods,svc

minikube service inventario-service --url
```

Con la URL que entregue Minikube:

```powershell
$url = "PEGAR_URL_DE_MINIKUBE"
curl.exe "$url/health"
curl.exe "$url/version"
curl.exe "$url/api/products"
```

Para demostrar la perdida de datos locales:

1. Abrir la app con `minikube service inventario-service`.
2. Crear un producto desde la interfaz.
3. Eliminar un pod:

```powershell
kubectl get pods -l app=inventario-app
kubectl delete pod NOMBRE_DEL_POD
kubectl get pods -w
```

Al volver a consultar la app, el producto puede desaparecer o aparecer segun el pod que atienda la peticion. Esto ocurre porque cada pod tiene su propio archivo JSON local.

## 5. Blue-Green

Se eligio Blue-Green porque esta app permite distinguir versiones por variables de entorno (`APP_VERSION` y `APP_COLOR`) y conviene demostrar un cambio del 100% del trafico de forma inmediata con recursos nativos de Kubernetes: dos `Deployment` y un `Service` cuyo selector cambia de `v1` a `v2`.

Crear primero el Secret que necesita la version Green. El valor se genera en la terminal y no se guarda en archivos versionados.

```powershell
$env:API_KEY_VALUE = "api-" + [guid]::NewGuid().ToString()
kubectl create secret generic api-secret --from-literal=API_KEY="$env:API_KEY_VALUE" --dry-run=client -o yaml | kubectl apply -f -
Remove-Item Env:\API_KEY_VALUE
```

Aplicar Blue, Green y el Service apuntando inicialmente a Blue:

```powershell
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service.yaml

kubectl rollout status deployment/inventario-app-blue
kubectl rollout status deployment/inventario-app-green
kubectl get pods -l app=inventario-app

minikube service inventario-service-bg --url
```

Antes del corte debe responder `v1`:

```powershell
$bgUrl = "PEGAR_URL_DE_MINIKUBE_BG"
curl.exe "$bgUrl/version"
```

Corte de trafico a Green:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
kubectl get service inventario-service-bg -o yaml
curl.exe "$bgUrl/version"
```

Despues del corte debe responder `v2`.

## 6. Componentes adicionales

### Secretos

El Secret se crea con `kubectl create secret` y se consume con `secretKeyRef` en `k8s/blue-green/deployment-green.yaml`.

```powershell
kubectl exec deployment/inventario-app-green -- printenv API_KEY
git grep -n "mi-clave-super-secreta"
```

El segundo comando no debe devolver resultados.

### Escaneo con Trivy

El workflow escanea la imagen antes de publicarla:

```yaml
uses: aquasecurity/trivy-action@0.35.0
severity: CRITICAL
exit-code: '1'
```

Si Trivy encuentra vulnerabilidades `CRITICAL`, el job falla y los pasos `docker push` no se ejecutan.

### Readiness con arranque lento

La variable `STARTUP_DELAY_SECONDS` hace que `/health` devuelva `503` durante los primeros segundos de vida del proceso. En Green esta configurada en `20` segundos y el `readinessProbe` tolera ese arranque con `periodSeconds: 5` y `failureThreshold: 6`.

```powershell
kubectl rollout restart deployment/inventario-app-green
kubectl get pods -l app=inventario-app,version=v2 -w
```

En otra terminal, durante el arranque:

```powershell
$pod = kubectl get pods -l app=inventario-app,version=v2 -o jsonpath='{.items[0].metadata.name}'
kubectl describe pod $pod
```

En los eventos debe verse que la readiness probe falla temporalmente con HTTP 503 y luego el pod pasa a `READY 1/1`.

## 7. Datos para metricas DORA

Timestamps de commits:

```powershell
git log --pretty=format:"%h %cI %s"
```

Timestamps de GitHub Actions:

```powershell
$repo = "patrici0l/Practica-CI-CD"
Invoke-RestMethod -Headers @{"User-Agent"="curl"} "https://api.github.com/repos/$repo/actions/runs?per_page=10" |
  Select-Object -ExpandProperty workflow_runs |
  Select-Object head_sha,conclusion,created_at,updated_at,html_url
```

Registrar despliegue real al cluster:

```powershell
$sha = "PEGAR_HASH_COMPLETO_DEL_COMMIT"
Get-Date -Format o
kubectl set image deployment/inventario-app inventario-app=ghcr.io/patrici0l/practica-ci-cd:$sha
kubectl rollout status deployment/inventario-app
Get-Date -Format o
```

Calculos para el informe:

- Lead time for changes: hora final del `rollout status` menos timestamp del commit. Reportar al menos dos cambios.
- Frecuencia de despliegue: cantidad de promociones reales al Deployment (`kubectl set image` o equivalente) dividida entre los dias de trabajo.
- Change failure rate: despliegues que necesitaron rollback o correccion posterior dividido entre el total de despliegues, multiplicado por 100.
