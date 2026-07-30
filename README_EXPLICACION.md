# Explicacion del proyecto y cumplimiento de la practica

Este documento explica que se hizo sobre el proyecto original `inventario-app`, para que sirve cada archivo importante y como se cumple cada punto solicitado en la practica.

## 1. Que era el proyecto original

El ZIP original traia una aplicacion Node.js/Express local:

- `server.js`: servidor Express con rutas web, health check, version y API REST de productos.
- `db.js`: manejo de una base de datos local en archivo JSON.
- `public/index.html`: estructura de la interfaz web.
- `public/app.js`: logica del navegador para consultar version, listar productos, agregar y eliminar.
- `public/styles.css`: estilos de la interfaz.
- `server.test.js`: pruebas automaticas de la API.
- `package.json`: scripts `npm start` y `npm test`.
- `data/.gitkeep`: mantiene la carpeta `data` en Git.

Ese proyecto funcionaba localmente, pero no tenia Docker, GitHub Actions, GHCR, Kubernetes, Blue-Green, secretos, escaneo de seguridad ni readiness lento.

## 2. Donde estan los tests

Los tests estan en:

```text
C:\A_PROJECTS\PRACTICA CI-CD\inventario-app\server.test.js
```

El comando que los ejecuta es:

```powershell
npm test
```

Eso funciona porque `package.json` tiene:

```json
"test": "node --test"
```

Node.js busca y ejecuta archivos de prueba como `server.test.js`.

Las pruebas actuales validan:

- `GET /health` responde `200`.
- `GET /health` responde `503` durante `STARTUP_DELAY_SECONDS`.
- `GET /version` devuelve version y color.
- `POST /api/products` crea producto.
- `GET /api/products` lista productos.
- `DELETE /api/products/:id` elimina producto.
- `POST /api/products` sin `name` o `sku` responde `400`.

## 3. Cambios en `server.js`

Se agrego la variable:

```text
STARTUP_DELAY_SECONDS
```

Antes, `/health` respondia `200` casi inmediatamente.

Ahora, si se configura `STARTUP_DELAY_SECONDS`, la aplicacion responde temporalmente:

```json
{"status":"starting"}
```

con codigo HTTP `503`.

Despues del tiempo configurado, `/health` vuelve a responder:

```json
{"status":"ok"}
```

Esto se hizo para cumplir el componente adicional de readiness realista con arranque lento. Simula una aplicacion que tarda en estar lista, por ejemplo porque esta conectandose a una base de datos.

## 4. Archivo `Dockerfile`

Este archivo se creo para empaquetar la aplicacion en una imagen Docker.

Tiene dos etapas.

### Etapa 1: `test`

```dockerfile
FROM node:20-alpine AS test
RUN npm ci
COPY . .
RUN npm test
```

Esta etapa instala dependencias y ejecuta las pruebas.

Importancia:

- Si las pruebas fallan, el build falla.
- Cumple la restriccion de la practica: el Dockerfile debe fallar si `npm test` falla.

### Etapa 2: `runner`

```dockerfile
FROM node:20-alpine AS runner
RUN npm ci --omit=dev
COPY --from=test /app/server.js .
COPY --from=test /app/db.js .
COPY --from=test /app/public/ ./public/
CMD ["node", "server.js"]
```

Esta etapa crea la imagen final. Copia solo lo necesario para ejecutar la app.

Tambien se agrego:

```dockerfile
RUN apk upgrade --no-cache
```

para actualizar paquetes del sistema base.

Y se elimina `npm`/`npx` de la imagen final:

```dockerfile
rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx
```

Esto se hizo porque Trivy detecto una vulnerabilidad critica en una dependencia incluida dentro de `npm`. Como la imagen final solo necesita ejecutar `node server.js`, `npm` no es necesario en produccion.

## 5. Archivo `.dockerignore`

Evita que Docker copie archivos innecesarios al contexto de build.

Ejemplos:

- `node_modules`
- `.git`
- `data/`
- logs

Esto hace el build mas limpio, rapido y seguro.

## 6. Archivo `.github/workflows/ci-cd.yml`

Este archivo crea el pipeline de GitHub Actions.

Tiene dos jobs.

### Job `build-test`

Ejecuta:

```powershell
npm ci
npm test
```

Sirve para validar que el codigo funciona antes de construir la imagen.

### Job `build-push`

Tiene:

```yaml
needs: build-test
```

Eso significa que solo se ejecuta si `build-test` pasa.

Este job:

1. Inicia sesion en GitHub Container Registry.
2. Define dos tags de imagen:
   - hash completo del commit.
   - `latest`.
3. Descarga `node:20-alpine` con reintentos.
4. Construye la imagen Docker.
5. Escanea la imagen con Trivy.
6. Publica la imagen con hash del commit.
7. Publica la imagen con `latest`.

Esto cumple:

- Pipeline fail-fast.
- Build automatico.
- Escaneo de seguridad.
- Publicacion automatica en GHCR.

## 7. GHCR

La imagen se publica en:

```text
ghcr.io/patrici0l/practica-ci-cd
```

Se publica con:

- Tag `latest`.
- Tag con el hash completo del commit.

Esto cumple la orden de publicar la imagen en GitHub Container Registry.

## 8. Archivo `k8s/deployment.yaml`

Este manifiesto despliega la aplicacion base en Kubernetes.

Puntos importantes:

```yaml
replicas: 2
```

Cumple el minimo de dos replicas.

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1
    maxSurge: 1
```

Cumple rolling update. Kubernetes actualiza gradualmente sin bajar todo el servicio.

```yaml
readinessProbe:
  httpGet:
    path: /health
```

Readiness indica cuando el pod esta listo para recibir trafico.

```yaml
livenessProbe:
  httpGet:
    path: /health
```

Liveness indica si el contenedor sigue sano o debe reiniciarse.

La imagen usada es:

```yaml
ghcr.io/patrici0l/practica-ci-cd:latest
```

## 9. Archivo `k8s/service.yaml`

Expone el Deployment base mediante NodePort.

Selector:

```yaml
app: inventario-app
```

Eso hace que el Service envie trafico a los pods del Deployment base.

Tipo:

```yaml
type: NodePort
```

Se usa porque Minikube permite abrir servicios NodePort en el navegador.

## 10. Carpeta `k8s/blue-green/`

Aqui se implemento la segunda estrategia de despliegue: Blue-Green.

La practica pedia Blue-Green o Canary. Se eligio Blue-Green porque la app permite distinguir versiones con:

- `APP_VERSION`
- `APP_COLOR`

Asi se puede demostrar visualmente el cambio de trafico.

## 11. Archivo `k8s/blue-green/deployment-blue.yaml`

Crea la version Blue.

Tiene:

```yaml
APP_VERSION: v1
APP_COLOR: blue
version: v1
```

Representa la version inicial o estable.

## 12. Archivo `k8s/blue-green/deployment-green.yaml`

Crea la version Green.

Tiene:

```yaml
APP_VERSION: v2
APP_COLOR: green
version: v2
```

Representa la nueva version.

Tambien incluye el Secret:

```yaml
valueFrom:
  secretKeyRef:
    name: api-secret
    key: API_KEY
```

Esto cumple manejo de secretos.

Tambien incluye:

```yaml
STARTUP_DELAY_SECONDS: "20"
```

Esto cumple readiness lento.

Y ajusta el readiness probe:

```yaml
periodSeconds: 5
failureThreshold: 6
```

Eso permite tolerar el arranque lento antes de enviar trafico al pod.

## 13. Archivo `k8s/blue-green/service.yaml`

Este Service controla a que version va el trafico.

Inicialmente apunta a Blue:

```yaml
selector:
  app: inventario-app
  version: v1
```

Luego se cambia a Green con:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
```

Esto demuestra el corte de trafico de Blue a Green usando solo recursos nativos de Kubernetes.

## 14. Secret de Kubernetes

No se creo un YAML con el secreto porque la practica pedia que la credencial no quede versionada en Git.

Se crea desde terminal:

```powershell
kubectl create secret generic api-secret --from-literal=API_KEY="valor"
```

Luego Green lo consume como variable de entorno.

Explicacion corta:

> El secreto vive en Kubernetes, no en el repositorio.

## 15. Trivy

Trivy se ejecuta dentro de GitHub Actions antes de publicar la imagen.

Configuracion clave:

```yaml
severity: CRITICAL
exit-code: '1'
```

Si existe una vulnerabilidad critica, el pipeline falla.

Problema real encontrado:

- Trivy detecto una vulnerabilidad critica en `tar`, incluida dentro del `npm` de la imagen base.

Solucion:

- Quitar `npm` y `npx` de la imagen final.

Esto demuestra que el escaneo funciono realmente.

## 16. README.md

El README principal documenta comandos para:

- Ejecutar localmente.
- Construir Docker.
- Probar endpoints.
- Revisar GitHub Actions.
- Desplegar en Kubernetes.
- Probar Blue-Green.
- Crear Secret.
- Probar readiness.
- Obtener datos DORA.

Esto cumple la exigencia de documentar comandos exactos reproducibles.

## 17. Archivos `patch-*.json`

Hay archivos auxiliares:

- `patch-service.json`
- `patch-deployment.json`
- `patch-bg-v2.json`

Sirven como apoyo para aplicar cambios con `kubectl patch`.

No son la parte principal de la practica, pero ayudan a guardar parches usados durante pruebas de despliegue.

## 18. Como se cumple la orden

| Requisito | Archivo o evidencia |
|---|---|
| App local funcionando | `npm start`, `server.js`, `public/` |
| Tests locales | `server.test.js`, `npm test` |
| Dockerfile multi-stage | `Dockerfile` |
| Build falla si tests fallan | `RUN npm test` en etapa `test` |
| Imagen final minima | Segunda etapa `runner` |
| GitHub Actions | `.github/workflows/ci-cd.yml` |
| `build-push` depende de tests | `needs: build-test` |
| Publicacion GHCR | `ghcr.io/patrici0l/practica-ci-cd` |
| Rolling update | `k8s/deployment.yaml` |
| Service base | `k8s/service.yaml` |
| 2 replicas | `replicas: 2` |
| readiness/liveness | probes a `/health` |
| Blue-Green | `k8s/blue-green/` |
| Cambio de trafico | patch del selector del Service |
| Secret | `api-secret` y `secretKeyRef` |
| Trivy | paso `Escanear imagen con Trivy` |
| Readiness lento | `STARTUP_DELAY_SECONDS` |
| Perdida de datos al borrar pod | base JSON local en `db.js` |
| README reproducible | `README.md` |

## 19. Explicacion final para exposicion

El proyecto original era una app Node.js local con interfaz, API y base JSON. Sobre esa base se construyo un flujo CI/CD completo. Primero se creo un Dockerfile multi-stage que ejecuta pruebas antes de generar la imagen final. Luego se automatizo con GitHub Actions: el job `build-test` valida el codigo y `build-push` solo corre si las pruebas pasan. Ese segundo job construye, escanea con Trivy y publica la imagen en GHCR.

Despues se desplego la imagen en Kubernetes con dos replicas, rolling update y probes de salud. Para la estrategia avanzada se uso Blue-Green con dos Deployments: Blue v1 y Green v2. El trafico se cambia modificando el selector del Service. Ademas se implementaron secretos con Kubernetes Secret, escaneo de seguridad con Trivy y readiness lento con `STARTUP_DELAY_SECONDS`.

La perdida de datos al recrear pods ocurre porque la base es un archivo JSON local dentro del contenedor. Si el pod se elimina, el nuevo pod arranca con datos iniciales. Esto demuestra por que en produccion se necesita una base de datos externa o almacenamiento persistente.
