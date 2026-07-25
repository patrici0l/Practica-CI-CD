# inventario-app con CI/CD Completo

Este repositorio contiene la aplicación **inventario-app** modificada para cumplir con todos los requerimientos de la práctica de CI/CD. Incluye el proceso de automatización desde la construcción de imágenes hasta estrategias de despliegue avanzado en Kubernetes con buenas prácticas.

## Qué es

Una app Node.js/Express con:
- **Interfaz web** para listar, crear y borrar productos del inventario.
- **Base de datos local efímera** (`db.js`) basada en un JSON local (demostrando la volatilidad de los Pods en K8s).
- **API REST**.

---

## 1. Ejecutar localmente (Sin Docker)

```bash
# 1. Instalar dependencias
npm install

# 2. Correr pruebas unitarias
npm test

# 3. Iniciar la aplicación
npm start
# Abrir en navegador: http://localhost:3000
```

---

## 2. Dockerización (Dockerfile Multi-stage)

El proyecto cuenta con un `Dockerfile` multi-etapa que sigue el principio **fail-fast**: ejecuta las pruebas durante la construcción y falla si no pasan, evitando crear imágenes defectuosas.

**Comandos para probar localmente:**
```bash
# Construir la imagen
docker build -t inventario-app:local .

# Ejecutar el contenedor
docker run -d -p 3000:3000 --name mi-inventario inventario-app:local

# Detenerlo y borrarlo
docker rm -f mi-inventario
```

---

## 3. Pipeline CI/CD en GitHub Actions

El archivo `.github/workflows/ci-cd.yml` orquesta la construcción, prueba y despliegue hacia **GitHub Container Registry (ghcr.io)**. 
- Contiene dos jobs: `build-test` y `build-push`.
- Etiqueta automáticamente la imagen con el hash del commit y la etiqueta `latest`.
- **Componente adicional (Escaneo de Seguridad):** Integra `Trivy` para escanear la imagen localmente buscando vulnerabilidades. El pipeline está configurado para **fallar** si encuentra vulnerabilidades de severidad `CRITICAL`.

**Reproducir:** Basta con hacer un `git push` a la rama `main` para detonar el flujo.

---

## 4. Estrategia de Despliegue: Blue-Green

Se eligió **Blue-Green** porque la aplicación puede cambiar su versión visual únicamente pasando variables de entorno (`APP_VERSION` y `APP_COLOR`), sin requerir compilar una nueva imagen. Esto permite redireccionar todo el tráfico (100%) sin interrupción del servicio (Zero-downtime).

**Comandos para reproducir la demostración:**

```bash
# 1. Aplicar la versión Blue y el Service
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service.yaml

# 2. Verificar que ambos deployments están arriba
kubectl get pods

# 3. Acceder al servicio (Mostrará versión v1 - Blue)
minikube service inventario-service-bg
```

Para hacer el **corte de tráfico**:
1. Editar `k8s/blue-green/service.yaml` y cambiar el selector `version: v1` por `version: v2`.
2. Aplicar el cambio:
```bash
kubectl apply -f k8s/blue-green/service.yaml
```
3. Refrescar el navegador: El cambio a la versión Green (v2) será instantáneo.

---

## 5. Componentes de Buenas Prácticas Implementados

Para obtener los puntos extra de la rúbrica, se implementaron **los tres componentes adicionales**.

### A. Manejo de Secretos (SecretManagement)
Se evita exponer secretos en el código o en los manifiestos YAML guardados en Git.
**Reproducir:**
```bash
# 1. Crear el secreto directamente en el clúster
kubectl create secret generic api-secret --from-literal=API_KEY=mi-clave-super-secreta-123

# 2. Aplicar el Deployment Green que inyecta el secreto como variable de entorno
kubectl apply -f k8s/blue-green/deployment-green.yaml

# 3. Entrar al pod para comprobar que la variable existe
kubectl exec -it deployment/inventario-app-green -- sh -c 'echo $API_KEY'
```

### B. Escaneo de Seguridad en CI (Trivy)
Implementado directamente en el archivo `.github/workflows/ci-cd.yml` (sección 3). Trivy bloquea el despliegue si detecta fallas críticas en el sistema operativo o librerías de la imagen base.

### C. Readiness Realista (Arranque Lento)
Se modificó `server.js` para incluir un tiempo de bloqueo de inicio gobernado por la variable de entorno `STARTUP_DELAY_SECONDS`. Durante ese tiempo, `/health` devuelve código `503`.
**Reproducir:**
1. En `k8s/blue-green/deployment-green.yaml`, la variable `STARTUP_DELAY_SECONDS` está definida en `20`.
2. El `readinessProbe` tiene un `failureThreshold: 6` y un `periodSeconds: 5` (tolera 30 segundos de espera total).
3. Kubernetes monitoreará y no matará prematuramente el contenedor, marcándolo como "Ready" recién a partir de los 20 segundos. 
```bash
# Observa cómo el pod tarda 20 segundos en pasar al estado READY 1/1
kubectl get pods -w
```
