# Practica CI/CD - Inventario App

Aplicacion Node.js/Express usada para demostrar una practica completa de CI/CD con pruebas automatizadas, Docker, GitHub Actions, GHCR, Kubernetes, despliegue rolling update, estrategia blue-green, secretos, readiness probe y metricas DORA.

Repositorio: https://github.com/patrici0l/Practica-CI-CD

Autor: Angel Patricio Lucero Loja

## Que demuestra esta practica

El objetivo no es solo levantar una aplicacion. La practica demuestra que un cambio de codigo puede pasar por una cadena controlada:

1. El codigo se prueba localmente con `npm test`.
2. Docker construye la imagen, pero primero ejecuta los tests dentro del build.
3. GitHub Actions repite las pruebas en la nube.
4. Si las pruebas pasan, se construye la imagen.
5. Trivy escanea la imagen antes de publicarla.
6. Si no hay vulnerabilidades criticas, la imagen se publica en GHCR.
7. Kubernetes despliega la imagen usando `Deployment`, `Service`, probes y replicas.
8. Blue-Green permite cambiar el trafico de la version `v1` a la version `v2` modificando el selector del Service.

## Archivos importantes

| Archivo | Para que sirve | Como cumple la practica |
|---|---|---|
| `server.js` | Servidor Express de la aplicacion. Define rutas como `/`, `/health`, `/version` y `/api/products`. | Permite probar salud, version de despliegue y comportamiento de la app dentro de Kubernetes. |
| `db.js` | Maneja la base de datos local en JSON. | Sirve para demostrar que los datos dentro de un pod son efimeros si no se usa volumen persistente. |
| `server.test.js` | Pruebas automatizadas con el test runner nativo de Node. | Valida endpoints principales antes de construir o publicar la imagen. |
| `package.json` | Define scripts y dependencias. | El script `"test": "node --test"` es el que ejecuta las pruebas. |
| `Dockerfile` | Construye la imagen en dos etapas. | La primera etapa ejecuta `npm test`; si falla, no se genera imagen final. |
| `.dockerignore` | Excluye archivos innecesarios del contexto Docker. | Evita subir `node_modules` y archivos locales al build. |
| `.github/workflows/ci-cd.yml` | Pipeline de GitHub Actions. | Ejecuta test, build, escaneo Trivy y publicacion en GHCR. |
| `k8s/deployment.yaml` | Deployment base de Kubernetes. | Ejecuta 2 replicas con rolling update, readiness probe y liveness probe. |
| `k8s/service.yaml` | Service NodePort base. | Expone la aplicacion en Minikube mediante `inventario-service`. |
| `k8s/blue-green/deployment-blue.yaml` | Version Blue (`v1`). | Representa la version estable inicial. |
| `k8s/blue-green/deployment-green.yaml` | Version Green (`v2`). | Representa la nueva version, usa Secret y arranque lento para probar readiness. |
| `k8s/blue-green/service.yaml` | Service para Blue-Green. | Cambia el trafico entre `v1` y `v2` con el selector `version`. |

## 1. Correr local

Este paso comprueba que la aplicacion funciona sin Docker ni Kubernetes. Es lo primero que se debe mostrar porque confirma que el codigo base esta bien.

```powershell
cd "C:\A_PROJECTS\PRACTICA CI-CD\inventario-app"
npm ci
npm test
npm start
```

Abrir en el navegador:

```text
http://localhost:3000
```

Probar endpoints importantes:

```powershell
curl.exe http://localhost:3000/health
curl.exe http://localhost:3000/version
curl.exe http://localhost:3000/api/products
```

Que se debe explicar:

- `npm ci` instala dependencias usando exactamente `package-lock.json`.
- `npm test` ejecuta las pruebas de `server.test.js`.
- `npm start` levanta el servidor con `node server.js`.
- `/health` se usa para saber si la app esta lista.
- `/version` ayuda a identificar si responde la version Blue o Green.

## 2. Pruebas automatizadas

Las pruebas estan en:

```text
server.test.js
```

El comando que las ejecuta esta en `package.json`:

```json
"test": "node --test"
```

Comando:

```powershell
npm test
```

Por que importa:

- Evita publicar una imagen si la app no responde correctamente.
- Es la primera puerta de calidad del pipeline.
- Tambien se ejecuta dentro del `Dockerfile`, no solo en la maquina local.

## 3. Docker local

El `Dockerfile` es multi-stage:

- Etapa `test`: instala dependencias, copia el codigo y ejecuta `npm test`.
- Etapa `runner`: crea la imagen final de produccion.

Construir y ejecutar:

```powershell
docker build --no-cache -t inventario-app:local .
docker run -d -p 3000:3000 --name mi-inventario inventario-app:local
```

Probar:

```powershell
curl.exe http://localhost:3000/health
curl.exe http://localhost:3000/version
curl.exe http://localhost:3000/api/products
```

Limpiar:

```powershell
docker rm -f mi-inventario
```

Que se debe explicar:

- Si `npm test` falla dentro del `Dockerfile`, el build se detiene.
- La imagen final queda mas limpia porque solo copia lo necesario.
- La carpeta `data` vive dentro del contenedor, por eso sus datos no son persistentes.

## 4. Pipeline CI/CD en GitHub Actions

Archivo:

```text
.github/workflows/ci-cd.yml
```

El pipeline tiene dos jobs:

| Job | Que hace | Importancia |
|---|---|---|
| `build-test` | Ejecuta `npm ci` y `npm test`. | Verifica el codigo antes de construir imagen. |
| `build-push` | Construye imagen, escanea con Trivy y publica en GHCR. | Solo corre si `build-test` fue exitoso. |

Subir cambios para activar el pipeline:

```powershell
git add .
git commit -m "fix: completar practica ci cd"
git push origin main
```

Ver ultimas ejecuciones desde PowerShell:

```powershell
$repo = "patrici0l/Practica-CI-CD"
Invoke-RestMethod -Headers @{"User-Agent"="curl"} "https://api.github.com/repos/$repo/actions/runs?per_page=5" |
  Select-Object -ExpandProperty workflow_runs |
  Select-Object head_sha,status,conclusion,created_at,updated_at,html_url
```

Imagen publicada:

```text
ghcr.io/patrici0l/practica-ci-cd:latest
ghcr.io/patrici0l/practica-ci-cd:<hash-del-commit>
```

Que se debe explicar:

- `needs: build-test` obliga a que `build-push` espere las pruebas.
- Primero se prueba, luego se construye, luego se escanea y al final se publica.
- Se publican dos tags: uno fijo por commit y uno llamado `latest`.

## 5. Escaneo con Trivy

Trivy esta dentro del pipeline:

```yaml
uses: aquasecurity/trivy-action@0.35.0
severity: CRITICAL
exit-code: '1'
```

Que significa:

- Revisa vulnerabilidades del sistema operativo y librerias.
- Si encuentra vulnerabilidades `CRITICAL`, el job falla.
- Si el job falla, no se ejecutan los pasos de `docker push`.

## 6. Kubernetes base

Aplicar Deployment y Service:

```powershell
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl rollout status deployment/inventario-app
kubectl get pods -l app=inventario-app --show-labels
kubectl get svc inventario-service
```

Abrir con Minikube:

```powershell
minikube service inventario-service --url
```

Usar la URL que entregue Minikube:

```powershell
$url = "PEGAR_URL_DE_MINIKUBE"
curl.exe "$url/health"
curl.exe "$url/version"
curl.exe "$url/api/products"
```

Que se debe explicar:

- `Deployment` mantiene el numero deseado de pods.
- `replicas: 2` significa que Kubernetes intenta mantener 2 pods de la app.
- `Service` expone los pods aunque sus nombres cambien.
- `readinessProbe` evita enviar trafico a un pod que todavia no esta listo.
- `livenessProbe` permite reiniciar un contenedor si deja de responder.

## 7. Sobre tener muchos pods

Es normal ver varios pods si en el mismo Minikube hay otros proyectos o servicios. Para esta practica se deben mirar solo los pods de inventario:

```powershell
kubectl get pods -l app=inventario-app --show-labels
```

Si aparecen pods `Pending`, normalmente falta CPU o memoria en Minikube. Para limpiar solo esta practica:

```powershell
kubectl delete -f k8s/blue-green/service.yaml
kubectl delete -f k8s/blue-green/deployment-green.yaml
kubectl delete -f k8s/blue-green/deployment-blue.yaml
kubectl delete -f k8s/service.yaml
kubectl delete -f k8s/deployment.yaml
```

No borrar pods uno por uno para eliminar definitivamente una app. Si se borra solo el pod, el Deployment lo vuelve a crear.

## 8. Prueba de datos efimeros

La app guarda productos en un archivo JSON local dentro del pod. Eso sirve para demostrar que un contenedor no debe usarse como almacenamiento permanente.

Pasos:

```powershell
kubectl get pods -l app=inventario-app
```

Crear un producto desde la interfaz o por API:

```powershell
$url = "PEGAR_URL_DE_MINIKUBE"
curl.exe -X POST "$url/api/products" `
  -H "Content-Type: application/json" `
  -d "{\"name\":\"Producto demo\",\"sku\":\"DEMO-001\",\"stock\":5,\"price\":10}"
```

Borrar un pod:

```powershell
kubectl delete pod NOMBRE_DEL_POD
kubectl get pods -l app=inventario-app -w
```

Explicacion:

- Kubernetes crea un pod nuevo para volver a cumplir las replicas.
- El nuevo pod no necesariamente conserva el JSON del pod eliminado.
- Esto demuestra la necesidad de volumen persistente o base de datos externa.

## 9. Blue-Green deployment

Blue-Green usa dos Deployments:

| Version | Archivo | Variable | Rol |
|---|---|---|---|
| Blue | `k8s/blue-green/deployment-blue.yaml` | `APP_VERSION=v1` | Version estable inicial. |
| Green | `k8s/blue-green/deployment-green.yaml` | `APP_VERSION=v2` | Nueva version candidata. |

El Service empieza apuntando a Blue:

```yaml
selector:
  app: inventario-app
  version: v1
```

Crear Secret para Green:

```powershell
$env:API_KEY_VALUE = "api-" + [guid]::NewGuid().ToString()
kubectl create secret generic api-secret --from-literal=API_KEY="$env:API_KEY_VALUE" --dry-run=client -o yaml | kubectl apply -f -
Remove-Item Env:\API_KEY_VALUE
```

Aplicar Blue, Green y Service:

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

Probar que responde Blue:

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

Que se debe explicar:

- No se cambia el codigo para mover el trafico.
- El cambio se hace modificando el selector del Service.
- Blue y Green pueden estar vivos al mismo tiempo.
- Esto permite validar Green antes de enviarle trafico.

## 10. Secret en Kubernetes

Green usa una variable `API_KEY` tomada desde un Secret:

```yaml
valueFrom:
  secretKeyRef:
    name: api-secret
    key: API_KEY
```

Verificar que existe:

```powershell
kubectl get secret api-secret
kubectl describe secret api-secret
```

Verificar que el valor no quedo escrito en archivos:

```powershell
git grep -n "mi-clave-super-secreta"
```

Explicacion:

- El secreto no se sube al repositorio.
- Kubernetes lo inyecta como variable de entorno.
- Es mejor que escribir claves dentro de YAML versionado.

## 11. Readiness probe con arranque lento

En Green se agrego:

```yaml
STARTUP_DELAY_SECONDS: "20"
```

Eso hace que `/health` responda temporalmente `503` durante el arranque. Kubernetes no manda trafico al pod hasta que la readiness probe responda bien.

Probar:

```powershell
kubectl rollout restart deployment/inventario-app-green
kubectl get pods -l app=inventario-app,version=v2 -w
```

En otra terminal:

```powershell
$pod = kubectl get pods -l app=inventario-app,version=v2 -o jsonpath='{.items[0].metadata.name}'
kubectl describe pod $pod
```

Que se debe explicar:

- `readinessProbe` decide si el pod puede recibir trafico.
- Al inicio puede fallar con HTTP 503.
- Cuando la app termina de arrancar, el pod pasa a `READY 1/1`.

## 12. Metricas DORA

Para calcular lead time:

```powershell
git log --pretty=format:"%h %cI %s"
```

Para ver tiempos de GitHub Actions:

```powershell
$repo = "patrici0l/Practica-CI-CD"
Invoke-RestMethod -Headers @{"User-Agent"="curl"} "https://api.github.com/repos/$repo/actions/runs?per_page=10" |
  Select-Object -ExpandProperty workflow_runs |
  Select-Object head_sha,conclusion,created_at,updated_at,html_url
```

Para registrar un despliegue real:

```powershell
$sha = "PEGAR_HASH_COMPLETO_DEL_COMMIT"
Get-Date -Format o
kubectl set image deployment/inventario-app inventario-app=ghcr.io/patrici0l/practica-ci-cd:$sha
kubectl rollout status deployment/inventario-app
Get-Date -Format o
```

Como explicarlo:

- Lead time: tiempo entre commit y despliegue en cluster.
- Deployment frequency: cuantas veces se desplego en el periodo de practica.
- Change failure rate: porcentaje de despliegues que fallaron o necesitaron correccion.
- MTTR: tiempo de recuperacion si un cambio fallo.

## Comandos clave para exponer

Estos son los comandos mas importantes para mostrar en clase:

```powershell
cd "C:\A_PROJECTS\PRACTICA CI-CD\inventario-app"

npm test

docker build --no-cache -t inventario-app:local .
docker run -d -p 3000:3000 --name mi-inventario inventario-app:local
curl.exe http://localhost:3000/health
docker rm -f mi-inventario

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

## Guion corto para explicar

Este proyecto toma una aplicacion de inventario y la convierte en una practica completa de CI/CD. Primero se agregaron pruebas automatizadas en `server.test.js`. Luego se modifico el `Dockerfile` para que la imagen solo se construya si las pruebas pasan. Despues se creo un pipeline en GitHub Actions que ejecuta las pruebas, construye la imagen, la escanea con Trivy y la publica en GHCR.

En Kubernetes se agrego un Deployment base con dos replicas, rolling update, readiness probe y liveness probe. Tambien se agrego una estrategia Blue-Green con dos Deployments: Blue como version `v1` y Green como version `v2`. El cambio de version no se hace recreando todo, sino cambiando el selector del Service. Finalmente, Green usa un Secret y un arranque lento para demostrar que Kubernetes espera a que el pod este listo antes de enviarle trafico.
