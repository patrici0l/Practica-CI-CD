# Guia de exposicion: comandos para demostrar la practica

Ejecutar todos los comandos desde:

```powershell
cd "C:\A_PROJECTS\PRACTICA CI-CD\inventario-app"
```

Esta guia esta pensada para exponer la practica de inicio a fin. Cada bloque indica que comando ejecutar y que demuestra.

## 0. Revisar archivos principales

```powershell
dir
dir k8s
dir k8s\blue-green
dir .github\workflows
```

Que explico:

> Aqui se ven los archivos agregados para la practica: Dockerfile, workflow de GitHub Actions, manifiestos Kubernetes y la carpeta Blue-Green.

## 1. Probar la app local

```powershell
npm ci
npm test
```

Que demuestra:

- Las dependencias se instalan correctamente.
- Las pruebas automaticas pasan.
- Los tests estan en `server.test.js`.

Donde estan los tests:

```powershell
Get-Content .\server.test.js
```

Explicacion:

> `npm test` ejecuta `node --test`, definido en `package.json`. Node detecta y ejecuta `server.test.js`.

Para levantar la app local:

```powershell
npm start
```

Abrir:

```text
http://localhost:3000
```

Detener con `Ctrl + C`.

## 2. Construir la imagen Docker

```powershell
docker build --no-cache -t inventario-app:local .
```

Que debes mostrar:

- Etapa `test`.
- Linea `RUN npm test`.
- Tests pasando durante el build.

Explicacion:

> El Dockerfile es multi-stage. Primero prueba la aplicacion y luego crea la imagen final. Si los tests fallan, el build no continua.

## 3. Ejecutar la imagen Docker y probar endpoints

```powershell
docker run -d -p 3000:3000 --name mi-inventario inventario-app:local
```

Probar rutas:

```powershell
curl.exe http://localhost:3000/
curl.exe http://localhost:3000/health
curl.exe http://localhost:3000/version
curl.exe http://localhost:3000/api/products
```

Que demuestra:

- `/` carga la interfaz.
- `/health` responde estado de salud.
- `/version` muestra version y color.
- `/api/products` muestra la API REST.

Limpiar:

```powershell
docker rm -f mi-inventario
```

## 4. Probar readiness lento local

```powershell
docker run -d -p 3000:3000 --name mi-inventario-delay -e STARTUP_DELAY_SECONDS=10 inventario-app:local
```

Inmediatamente:

```powershell
curl.exe -i http://localhost:3000/health
```

Debe aparecer `503` o `starting`.

Despues de 10 segundos:

```powershell
curl.exe -i http://localhost:3000/health
```

Debe aparecer `200` y `ok`.

Limpiar:

```powershell
docker rm -f mi-inventario-delay
```

Explicacion:

> `STARTUP_DELAY_SECONDS` simula una app que tarda en estar lista. Kubernetes usara readiness para no enviar trafico antes de tiempo.

## 5. Escanear la imagen con Trivy local

```powershell
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --severity CRITICAL --pkg-types os,library --scanners vuln --format table inventario-app:local
```

Que demuestra:

- La imagen no debe tener vulnerabilidades criticas.
- Si Trivy encuentra una critica, en GitHub Actions el pipeline falla.

Explicacion:

> Trivy revisa vulnerabilidades de sistema y librerias. En la practica detecto un problema real en `npm`; por eso se elimino `npm/npx` de la imagen final.

## 6. Disparar GitHub Actions

Si quieres ejecutar el pipeline sin cambiar codigo:

```powershell
git status
git commit --allow-empty -m "test: ejecutar pipeline para exposicion"
git push origin main
```

Que demuestra:

- Cada push dispara GitHub Actions.
- Se ejecuta `build-test`.
- Si pasa, se ejecuta `build-push`.

Revisar en GitHub:

```text
https://github.com/patrici0l/Practica-CI-CD/actions
```

Que debes mostrar:

- `build-test` en verde.
- `build-push` en verde.
- Paso de Trivy.
- Pasos de publicacion.

## 7. Ver imagen publicada en GHCR

Abrir:

```text
https://github.com/patrici0l/Practica-CI-CD/pkgs/container/practica-ci-cd
```

Que demuestra:

- La imagen se publico en GHCR.
- Tiene tag `latest`.
- Tiene tag con hash del commit.

Explicacion:

> GHCR funciona como registro de contenedores. Kubernetes usa esa imagen para desplegar la app.

## 8. Iniciar Minikube

```powershell
minikube status
```

Si no esta corriendo:

```powershell
minikube start
```

Que demuestra:

> Minikube es el cluster Kubernetes local donde se despliega la practica.

## 9. Desplegar rolling update base

```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/inventario-app
kubectl get pods,svc
```

Que demuestra:

- Deployment base creado.
- Service creado.
- Rolling update exitoso.
- Pods corriendo.

Explicacion:

> El Deployment base usa dos replicas, rolling update y probes a `/health`.

Abrir la app:

```powershell
minikube service inventario-service
```

O usar URL:

```powershell
minikube service inventario-service --url
```

Si obtienes una URL, guardala:

```powershell
$url = "PEGA_AQUI_LA_URL"
curl.exe "$url/health"
curl.exe "$url/version"
curl.exe "$url/api/products"
```

## 10. Demostrar perdida de datos al recrear pod

Primero abre la app:

```powershell
minikube service inventario-service
```

Desde la interfaz, crea un producto nuevo.

Luego mira los pods:

```powershell
kubectl get pods -l app=inventario-app
```

Elimina uno:

```powershell
kubectl delete pod NOMBRE_DEL_POD
```

Observa la recreacion:

```powershell
kubectl get pods -w
```

Explicacion:

> El producto se guarda en el JSON local del pod que recibio la peticion. Si ese pod se elimina, el nuevo pod arranca limpio. No es un bug; es almacenamiento efimero.

Para salir de `-w`, usar `Ctrl + C`.

## 11. Crear el Secret de Kubernetes

```powershell
$env:API_KEY_VALUE = "api-" + [guid]::NewGuid().ToString()
kubectl create secret generic api-secret --from-literal=API_KEY="$env:API_KEY_VALUE" --dry-run=client -o yaml | kubectl apply -f -
Remove-Item Env:\API_KEY_VALUE
```

Verificar:

```powershell
kubectl get secret api-secret
```

Explicacion:

> El secreto se crea en Kubernetes, no se guarda en Git.

## 12. Desplegar Blue-Green

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

Que demuestra:

- Blue y Green corren al mismo tiempo.
- Blue tiene `version=v1`.
- Green tiene `version=v2`.

## 13. Probar Blue inicial

Obtener URL:

```powershell
minikube service inventario-service-bg --url
```

Guardar URL:

```powershell
$bgUrl = "PEGA_AQUI_LA_URL_BG"
```

Probar version:

```powershell
curl.exe "$bgUrl/version"
```

Debe salir:

```json
{"version":"v1","color":"blue"}
```

Explicacion:

> El Service Blue-Green inicialmente apunta al selector `version=v1`.

## 14. Cambiar trafico a Green

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
```

Ver selector:

```powershell
kubectl get service inventario-service-bg -o jsonpath='{.spec.selector}'
```

Probar version:

```powershell
curl.exe "$bgUrl/version"
```

Debe salir:

```json
{"version":"v2","color":"green"}
```

Explicacion:

> En Blue-Green no se destruye la version anterior. Se cambia el selector del Service para mover el trafico de Blue a Green.

## 15. Verificar Secret dentro de Green

```powershell
kubectl exec deployment/inventario-app-green -- printenv API_KEY
```

Verificar que no esta escrito en Git:

```powershell
git grep -n "mi-clave-super-secreta"
```

Si no devuelve resultados, esta bien.

Explicacion:

> El valor llega al contenedor por Kubernetes Secret, no por archivo versionado.

## 16. Probar readiness lento en Kubernetes

Reiniciar Green:

```powershell
kubectl rollout restart deployment/inventario-app-green
```

Observar pods:

```powershell
kubectl get pods -l app=inventario-app,version=v2 -w
```

En otra terminal:

```powershell
$pod = kubectl get pods -l app=inventario-app,version=v2 -o jsonpath='{.items[0].metadata.name}'
kubectl describe pod $pod
```

Que demostrar:

- Green tiene `STARTUP_DELAY_SECONDS=20`.
- Readiness apunta a `/health`.
- El pod pasa a `READY 1/1` cuando la app esta lista.

Explicacion:

> Readiness evita mandar trafico a un pod que ya arranco como proceso, pero todavia no esta listo como aplicacion.

## 17. Ver todos los pods y explicar por que hay varios

```powershell
kubectl get pods -l app=inventario-app --show-labels
```

Explicacion:

> Hay varios pods porque estan corriendo el Deployment base, Blue y Green. Cada Deployment puede tener replicas. Esto es normal durante la demostracion.

## 18. Obtener datos DORA

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

## 19. Limpieza opcional

Si quieres dejar solo el Deployment base:

```powershell
kubectl delete -f k8s/blue-green/service.yaml
kubectl delete -f k8s/blue-green/deployment-blue.yaml
kubectl delete -f k8s/blue-green/deployment-green.yaml
```

Si quieres borrar todo:

```powershell
kubectl delete -f k8s/blue-green/service.yaml
kubectl delete -f k8s/blue-green/deployment-blue.yaml
kubectl delete -f k8s/blue-green/deployment-green.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
kubectl delete secret api-secret
```

## 20. Guion corto para decir al final

> La practica parte de una app Node.js local. Se dockerizo con un Dockerfile multi-stage que ejecuta pruebas antes de construir la imagen final. Luego se automatizo con GitHub Actions: primero corre `build-test`, y si pasa, `build-push` construye, escanea con Trivy y publica en GHCR. En Kubernetes se desplego con dos replicas, rolling update, readiness y liveness. Para despliegue avanzado se uso Blue-Green con dos Deployments y un Service que cambia de selector. Tambien se implementaron Secret, escaneo de seguridad y readiness con arranque lento. La perdida de productos al borrar pods ocurre porque la base es un JSON local dentro del contenedor.
