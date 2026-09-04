# Build stage
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build -- --base-href /browser/

# Serve stage
FROM nginx:alpine
COPY --from=build /app/dist/front-t/browser /usr/share/nginx/html/browser
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
