# ── Stage 1: build the Flutter web app ───────────────────────────
# cirruslabs/flutter ships Flutter SDK + Dart preinstalled.
# Pinning to stable so the toolchain matches what we use locally.
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Pub deps in their own layer so a code-only change keeps this cached.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Now the source tree (lib/, web/, assets/, fonts/, etc.).
COPY . .

# --no-tree-shake-icons matches the local build/deploy convention so
# MaterialIcons keep working in production.
RUN flutter build web --release --no-tree-shake-icons

# ── Stage 2: serve with nginx ────────────────────────────────────
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
