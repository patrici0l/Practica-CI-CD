# --- ETAPA 1: Build y Test ---
FROM node:20-alpine AS builder
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

# Copiamos package.json y package-lock.json
COPY package*.json ./
# Instalamos SOLO dependencias de producción (más ligero y seguro)
RUN npm ci --omit=dev

# Copiamos el código fuente necesario (incluida la carpeta public)
COPY server.js .
COPY db.js .
COPY public/ ./public/
# Creamos la carpeta data donde la app guarda su base de datos JSON local
RUN mkdir data

# Exponemos el puerto
EXPOSE 3000

# Comando de inicio
CMD ["npm", "start"]