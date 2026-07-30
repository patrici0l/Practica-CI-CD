# Expo clase - comandos listos

Esta guia asume que Minikube ya dejo abierta esta URL:

```powershell
$bgUrl = "http://127.0.0.1:55449"
```

No cierres la terminal donde se ejecuto `minikube service inventario-service-bg --url`, porque en Windows con Docker esa terminal mantiene activa la URL.

## 1. Entrar al proyecto

```powershell
cd "C:\A_PROJECTS\PRACTICA CI-CD\inventario-app"
```

## 2. Guardar la URL Blue-Green

```powershell
$bgUrl = "http://127.0.0.1:55449"
```

## 3. Volver primero a Blue

Como el archivo `k8s/blue-green/service.yaml` apunta a `version: v1`, este comando deja el Service en Blue:

```powershell
kubectl apply -f k8s/blue-green/service.yaml
```

Verificar selector:

```powershell
kubectl get service inventario-service-bg -o jsonpath='{.spec.selector}'
```

Probar version:

```powershell
curl.exe "$bgUrl/version"
```

Debe salir algo como:

```json
{"version":"v1","color":"blue"}
```

## 4. Mostrar que existen Blue y Green

```powershell
kubectl get pods -l app=inventario-app --show-labels
```

Explicacion corta:

> Blue y Green existen al mismo tiempo. El Service decide a cual version enviar trafico.

## 5. Cambiar de Blue a Green

Este archivo ya contiene el patch para cambiar el selector a `version: v2`:

```powershell
Get-Content patch-bg-v2.json
```

Aplicar cambio a Green:

```powershell
kubectl patch service inventario-service-bg --type merge --patch-file patch-bg-v2.json
```

Verificar selector:

```powershell
kubectl get service inventario-service-bg -o jsonpath='{.spec.selector}'
```

Probar version:

```powershell
curl.exe "$bgUrl/version"
```

Debe salir algo como:

```json
{"version":"v2","color":"green"}
```

## 6. Volver de Green a Blue

```powershell
kubectl apply -f k8s/blue-green/service.yaml
curl.exe "$bgUrl/version"
```

Debe volver a:

```json
{"version":"v1","color":"blue"}
```

## 7. Docker y pipeline para mostrar

Mostrar Dockerfile:

```powershell
Get-Content Dockerfile
```

Construir imagen:

```powershell
docker build --no-cache -t inventario-app:local .
```

Mostrar pipeline:

```powershell
Get-Content .github\workflows\ci-cd.yml
```

Abrir Actions:

```text
https://github.com/patrici0l/Practica-CI-CD/actions
```

## 8. Frase para explicar

Blue-Green no cambia el codigo ni reconstruye la imagen durante la demostracion. Blue y Green ya estan desplegados. Lo unico que cambia es el selector del Service: cuando apunta a `version=v1`, responde Blue; cuando apunta a `version=v2`, responde Green.
