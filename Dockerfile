# Etapa 1: valida la aplicacion antes de crear la imagen final.
FROM node:20-alpine AS test
WORKDIR /app

# Copiar primero dependencias mejora la cache del build.
COPY package*.json ./
# Aqui van todas las dependencias porque se ejecutan pruebas.
RUN npm ci

COPY . .

# Punto clave: si los tests fallan, Docker no construye la imagen.
RUN npm test

# Etapa 2: imagen final de ejecucion.
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN apk upgrade --no-cache

COPY package*.json ./
# Solo dependencias de produccion para reducir peso y superficie de riesgo.
RUN npm ci --omit=dev \
  && npm cache clean --force \
  && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Se copia codigo desde la etapa que ya paso pruebas.
COPY --from=test /app/server.js .
COPY --from=test /app/db.js .
COPY --from=test /app/public/ ./public/

# La app guarda datos en JSON local; por eso no hay persistencia real entre pods.
RUN mkdir -p data

EXPOSE 3000

CMD ["node", "server.js"]
