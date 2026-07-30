# Expo clase - puntos importantes

Esta guia es solo para presentar la practica. No es para crear todo desde cero, porque el proyecto y los recursos ya estan hechos.

## 1. Entrar al proyecto

```powershell
cd "C:\A_PROJECTS\PRACTICA CI-CD\inventario-app"
```

## 2. Mostrar pruebas

```powershell
npm test
```

Explicacion corta:

> Las pruebas estan en `server.test.js`. El pipeline y el Dockerfile dependen de que estas pruebas pasen.

## 3. Mostrar Docker

Ver el Dockerfile:

```powershell
Get-Content Dockerfile
```

Construir imagen para demostrar:

```powershell
docker build --no-cache -t inventario-app:local .
```

Explicacion corta:

> El Dockerfile es multi-stage. Primero ejecuta `npm test`; si las pruebas fallan, la imagen no se construye.

## 4. Mostrar pipeline

Ver archivo del pipeline:

```powershell
Get-Content .github\workflows\ci-cd.yml
```

Abrir GitHub Actions:

```text
https://github.com/patrici0l/Practica-CI-CD/actions
```

Explicacion corta:

> El pipeline tiene `build-test` y `build-push`. Primero prueba, despues construye, escanea con Trivy y publica en GHCR.

## 5. Mostrar Kubernetes ya desplegado

Ver pods de la practica:

```powershell
kubectl get pods -l app=inventario-app --show-labels
```

Ver servicios:

```powershell
kubectl get svc
```

Explicacion corta:

> Kubernetes mantiene los pods activos con Deployments y los expone con Services.

## 6. Probar app base

Obtener URL:

```powershell
minikube service inventario-service --url
```

Probar:

```powershell
$url = "PEGAR_URL"
curl.exe "$url/health"
curl.exe "$url/version"
```

## 7. Mostrar Blue-Green

Ver Blue y Green:

```powershell
kubectl get deployments | Select-String "inventario-app"
kubectl get pods -l app=inventario-app --show-labels
```

Obtener URL Blue-Green:

```powershell
minikube service inventario-service-bg --url
```

Guardar URL:

```powershell
$bgUrl = "PEGAR_URL_BG"
```

Ver version actual:

```powershell
curl.exe "$bgUrl/version"
```

## 8. Cambiar de Blue a Green

Enviar trafico a Green:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v2"}}}'
curl.exe "$bgUrl/version"
```

Debe responder:

```json
{"version":"v2","color":"green"}
```

Volver a Blue:

```powershell
kubectl patch service inventario-service-bg -p '{"spec":{"selector":{"app":"inventario-app","version":"v1"}}}'
curl.exe "$bgUrl/version"
```

Debe responder:

```json
{"version":"v1","color":"blue"}
```

Explicacion corta:

> Blue-Green no reconstruye la imagen ni borra pods. Solo cambia el selector del Service para mover el trafico entre versiones.

## 9. Mostrar Secret y readiness

Ver Secret:

```powershell
kubectl get secret api-secret
```

Ver readiness de Green:

```powershell
kubectl describe deployment inventario-app-green
```

Explicacion corta:

> Green usa un Secret para `API_KEY` y tiene `STARTUP_DELAY_SECONDS=20`, por eso Kubernetes espera a que este listo antes de enviar trafico.

## Frase final

La practica ya esta implementada. Lo importante para presentar es que Docker valida las pruebas antes de construir, GitHub Actions automatiza test, build, Trivy y push a GHCR, y Kubernetes permite desplegar la app. El cambio Blue-Green se demuestra cambiando el selector del Service de `version=v1` a `version=v2`.
