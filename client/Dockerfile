# Development image for Docker Compose (Vite dev server with hot reload on port 3000)
FROM node:24-alpine

WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./
RUN npm ci

# Copy app (will be overridden by volume mount in compose for hot reload)
COPY . .

# Expose Vite dev server port
EXPOSE 3000

# Listen on 0.0.0.0 so host browser can reach via port mapping
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"]
