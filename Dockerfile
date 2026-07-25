# --- ETAPA 1: Dependencias y pruebas ---
FROM node:20-alpine AS test
WORKDIR /app

# Copiamos solo los archivos de dependencias primero (optimización de caché)
COPY package*.json ./
# Instalamos TODAS las dependencias (necesarias para testing)
RUN npm ci

# Copiamos el resto del código
COPY . .

# Corremos los tests. Si esto falla, el build de Docker se detiene (Fail-fast)
RUN npm test

# --- ETAPA 2: Imagen Final ---
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN apk upgrade --no-cache

# Copiamos package.json y package-lock.json
COPY package*.json ./
# Instalamos SOLO dependencias de producción (más ligero y seguro)
RUN npm ci --omit=dev \
  && npm cache clean --force \
  && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Copiamos el código fuente necesario desde la etapa que ya pasó las pruebas
COPY --from=test /app/server.js .
COPY --from=test /app/db.js .
COPY --from=test /app/public/ ./public/
# Creamos la carpeta data donde la app guarda su base de datos JSON local
RUN mkdir -p data

# Exponemos el puerto
EXPOSE 3000

# Comando de inicio
CMD ["node", "server.js"]
