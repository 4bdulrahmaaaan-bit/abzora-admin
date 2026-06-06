# Stage 1: Build the Flutter web application
FROM ghcr.io/cirruslabs/flutter:3.27.0 AS build

WORKDIR /app

# Copy the pubspec files first to leverage Docker cache
COPY pubspec.* ./
RUN flutter pub get

# Copy the rest of the application code
COPY . .

# Build the web application for production
# You can pass backend URL as an argument if needed:
# ARG BACKEND_BASE_URL=http://localhost:5000
# RUN flutter build web --release --dart-define=BACKEND_BASE_URL=$BACKEND_BASE_URL
RUN flutter build web --release

# Stage 2: Serve the application with Nginx
FROM nginx:alpine

# Copy the built web application to Nginx's html directory
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy the custom Nginx configuration for single page apps
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
