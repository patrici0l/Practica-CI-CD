# Expo clase - comandos completos de la practica CI/CD

Guia rapida para exponer en clase. Ejecuta los comandos desde PowerShell.

## 0. Entrar al proyecto

```powershell
cd "C:\A_PROJECTS\PRACTICA CI-CD\inventario-app"
```

Ver archivos principales:

```powershell
dir
dir .github\workflows
dir k8s
dir k8s\blue-green
```

Explicacion:

> El proyecto original era una app Node.js. Se agregaron Dockerfile, GitHub Actions y manifiestos Kubernetes para convertirla en una practica completa de CI/CD.

## 1. Probar dependencias y tests locales

```powershell
npm ci
npm test
```

Explicacion:

> `npm ci` instala dependencias exactas desde `package-lock.json`. `npm test` ejecuta `node --test`, que corre las pruebas ubicadas en `server.test.js`.

Mostrar donde estan los tests:

```powershell
Get-Content .\server.test.js
```

## 2. Levantar la app local sin Docker

```powershell
npm start
```

Abrir en navegador:

```text
http://localhost:3000
```

Detener:

```text
Ctrl + C
```

Explicacion:

> Esta prueba confirma que la app base funciona antes de contenerizarla.

## 3. Construir imagen Docker

```powershell
docker build --no-cache -t inventario-app:local .
```

Que mostrar:

- Etapa `test`.
- `RUN npm test`.
- Tests pasando dentro del build.

Explicacion:

> El Dockerfile es multi-stage. Primero prueba la aplicacion y solo despues genera la imagen final. Si los tests fallan, no se construye la imagen.

## 4. Ejecutar imagen Docker y probar endpoints

```powershell
docker run -d -p 3000:3000 --name mi-inventario inventario-app:local
```

Probar endpoints:

```powershell
curl.exe http://localhost:3000/
curl.exe http://localhost:3000/health
curl.exe http://localhost:3000/version
curl.exe http://localhost:3000/api/products
```

Limpiar:

```powershell
docker rm -f mi-inventario
```

Explicacion:

> Se confirma que la imagen Docker responde la interfaz, health check, version y API REST.

## 5. Probar readiness lento local

```powershell
docker run -d -p 3000:3000 --name mi-inventario-delay -e STARTUP_DELAY_SECONDS=10 inventario-app:local
```

Consultar apenas arranca:

```powershell
curl.exe -i http://localhost:3000/health
```

Debe verse `503` o `starting`.

Esperar 10 segundos y consultar otra vez:

```powershell
curl.exe -i http://localhost:3000/health
```

Debe verse `200` y `ok`.

Limpiar:

```powershell
docker rm -f mi-inventario-delay
```

Explicacion:

> `STARTUP_DELAY_SECONDS` simula que la app tarda en estar lista. Kubernetes usa esto con readiness para no enviar trafico antes de tiempo.

## 6. Escaneo local con Trivy

```powershell
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity CRITICAL --pkg-types os,library --scanners vuln --format table inventario-app:local
```

Explicacion:

> Trivy escanea la imagen. Si hubiera una vulnerabilidad critica, el pipeline de GitHub Actions tambien fallaria.

## 7. Ejecutar pipeline de GitHub Actions

Si quieres disparar un run nuevo sin cambiar codigo:

```powershell
git status
git commit --allow-empty -m "test: ejecutar pipeline para exposicion"
git push origin main
```

Abrir Actions:

```text
https://github.com/patrici0l/Practica-CI-CD/actions
```

Que mostrar:

- `build-test` en verde.
- `build-push` en verde.
- Paso `Escanear imagen con Trivy`.
- Paso `Publicar imagen con hash del commit`.
- Paso `Publicar imagen latest`.

Explicacion:

> GitHub Actions automatiza el CI/CD. Primero prueba con `build-test`; si pasa, `build-push` construye, escanea y publica.

## 8. Ver imagen publicada en GHCR

Abrir:

```text
https://github.com/patrici0l/Practica-CI-CD/pkgs/container/practica-ci-cd
```

Explicacion:

> La imagen queda publicada en GitHub Container Registry con `latest` y con el hash del commit.

## 9. Iniciar o verificar Minikube

```powershell
minikube status
```

Si esta apagado:

```powershell
minikube start
```

Explicacion:

> Minikube es el cluster Kubernetes local donde desplegamos la app.

## 10. Desplegar version base con rolling update

```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/inventario-app
kubectl get pods,svc
```

Explicacion:

> El Deployment base usa dos replicas, rolling update, readiness y liveness apuntando a `/health`.

Abrir app base:

```powershell
minikube service inventario-service
```

O sacar URL:

```powershell
minikube service inventario-service --url
```

Si usas URL:

```powershell
$url = "PEGA_AQUI_LA_URL"
curl.exe "$url/health"
curl.exe "$url/version"
curl.exe "$url/api/products"
```

## 11. Demostrar perdida de datos por pod efimero

Abrir la app:

```powershell
minikube service inventario-service
```

En la interfaz, crea un producto nuevo.

Listar pods:

```powershell
kubectl get pods -l app=inventario-app
```

Eliminar un pod:

```powershell
kubectl delete pod NOMBRE_DEL_POD
```

Ver recreacion:

```powershell
kubectl get pods -w
```

Salir con:

```text
Ctrl + C
```

Explicacion:

> Los productos se guardan en un JSON local dentro del pod. Si el pod se elimina, el nuevo pod arranca con datos iniciales. Esto demuestra que el almacenamiento del contenedor es efimero.

## 12. Crear Secret para Green

```powershell
$env:API_KEY_VALUE = "api-" + [guid]::NewGuid().ToString()
kubectl create secret generic api-secret --from-literal=API_KEY="$env:API_KEY_VALUE" --dry-run=client -o yaml | kubectl apply -f -
Remove-Item Env:\API_KEY_VALUE
kubectl get secret api-secret
```

Explicacion:

> El Secret se crea en Kubernetes. La clave no queda escrita en archivos del repositorio.

## 13. Desplegar Blue-Green

```powershell
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service.yaml
```

Esperar:

```powershell
kubectl rollout status deployment/inventario-app-blue
kubectl rollout status deployment/inventario-app-green
kubectl get pods -l app=inventario-app --show-labels
```

Explicacion:

> Blue y Green son dos Deployments distintos. Blue tiene `version=v1`; Green tiene `version=v2`.

## 14. Probar que el Service apunta a Blue

Obtener URL:

```powershell
minikube service inventario-service-bg --url
```

Guardar URL:

```powershell
$bgUrl = "PEGA_AQUI_LA_URL_BG"
```

Probar:

```powershell
curl.exe "$bgUrl/version"
```

Debe salir algo como:

```json
{"version":"v1","color":"blue"}
```

Explicacion:

> El Service Blue-Green inicialmente tiene selector `version=v1`, por eso envia trafico a Blue.

## 15. Cambiar trafico de Blue a Green

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
```

Ver selector:

```powershell
kubectl get service inventario-service-bg -o jsonpath='{.spec.selector}'
```

Probar otra vez:

```powershell
curl.exe "$bgUrl/version"
```

Debe salir:

```json
{"version":"v2","color":"green"}
```

Explicacion:

> El cambio Blue-Green se logra cambiando el selector del Service. No se necesita Argo Rollouts ni herramientas externas.

## 16. Volver trafico de Green a Blue

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v1"}}}'
curl.exe "$bgUrl/version"
```

Debe volver a:

```json
{"version":"v1","color":"blue"}
```

Explicacion:

> Blue-Green permite volver rapidamente a la version anterior cambiando otra vez el selector.

## 17. Verificar Secret dentro del pod Green

Primero pasar trafico o asegurarse de que Green existe:

```powershell
kubectl get pods -l app=inventario-app,version=v2
```

Ver variable:

```powershell
kubectl exec deployment/inventario-app-green -- printenv API_KEY
```

Buscar que la clave fija no este en Git:

```powershell
git grep -n "mi-clave-super-secreta"
```

Explicacion:

> `API_KEY` llega desde Kubernetes Secret mediante `secretKeyRef`.

## 18. Probar readiness lento en Kubernetes

Reiniciar Green:

```powershell
kubectl rollout restart deployment/inventario-app-green
```

Ver pods:

```powershell
kubectl get pods -l app=inventario-app,version=v2 -w
```

En otra terminal:

```powershell
$pod = kubectl get pods -l app=inventario-app,version=v2 -o jsonpath='{.items[0].metadata.name}'
kubectl describe pod $pod
```

Explicacion:

> Green tiene `STARTUP_DELAY_SECONDS=20`. Durante ese tiempo `/health` puede responder 503, y Kubernetes espera antes de marcar el pod como listo.

## 19. Ver todos los pods

```powershell
kubectl get pods -l app=inventario-app --show-labels
```

Explicacion:

> Es normal ver varios pods porque estan corriendo el Deployment base, Blue y Green. Cada Deployment puede tener replicas.

## 20. Datos DORA

Commits:

```powershell
git log --pretty=format:"%h %H %cI %s"
```

Runs de GitHub Actions:

```powershell
$repo = "patrici0l/Practica-CI-CD"
Invoke-RestMethod -Headers @{"User-Agent"="curl"} "https://api.github.com/repos/$repo/actions/runs?per_page=10" |
  Select-Object -ExpandProperty workflow_runs |
  Select-Object head_sha,conclusion,created_at,updated_at,html_url
```

Pods con timestamps:

```powershell
$pods = kubectl get pods -l app=inventario-app -o json | ConvertFrom-Json
foreach($p in $pods.items){
  $name=$p.metadata.name
  $created=$p.metadata.creationTimestamp
  $version=$p.metadata.labels.version
  $image=$p.spec.containers[0].image
  "$name`t$created`t$version`t$image"
}
```

Explicacion:

> Con estos datos se calcula lead time, frecuencia de despliegue y change failure rate.

## 21. Limpieza opcional

Eliminar Blue-Green:

```powershell
kubectl delete -f k8s/blue-green/service.yaml
kubectl delete -f k8s/blue-green/deployment-blue.yaml
kubectl delete -f k8s/blue-green/deployment-green.yaml
```

Eliminar base:

```powershell
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
```

Eliminar Secret:

```powershell
kubectl delete secret api-secret
```

## 22. Guion final para decir

> La app original solo funcionaba localmente. Se agrego un Dockerfile multi-stage para probar y construir la imagen. Luego GitHub Actions automatiza el pipeline: primero ejecuta tests, despues construye, escanea con Trivy y publica en GHCR. En Kubernetes se despliega con dos replicas y rolling update. Tambien se implemento Blue-Green con dos Deployments y un Service que cambia de selector para mover el trafico de v1 azul a v2 verde. Ademas se agregaron Secrets, readiness con arranque lento y evidencia de perdida de datos por usar JSON local dentro del pod.
