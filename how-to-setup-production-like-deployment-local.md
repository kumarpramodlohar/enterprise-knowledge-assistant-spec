# Production-like local EKA setup on macOS

This beginner guide runs Enterprise Knowledge Assistant (EKA) locally with Docker Desktop, HTTPS, Keycloak SSO, PostgreSQL/pgvector, Caddy, Spring Boot, and React.

> This is a local development environment. Keycloak uses `start-dev`; do not use this configuration unchanged in production.

## URLs

| URL | Service |
| --- | --- |
| `https://localhost:8443` | React frontend |
| `https://localhost:8443/api/...` | Spring Boot backend |
| `https://localhost:8443/auth/` | Keycloak |
| `https://localhost:8443/actuator/health` | Backend health check |

## Prerequisites

- macOS with Docker Desktop installed and running.
- Homebrew.
- These sibling folders:

```text
EnterpriseKnowledgeAssitance/
├── enterprise-knowledge-assistant-backend/
├── enterprise-knowledge-assistant-frontend/
├── enterprise-knowledge-assistant-spec/
└── infra/local/
```

Run commands from `EnterpriseKnowledgeAssitance` unless stated otherwise.

## 1. HTTPS certificate

```bash
brew install mkcert
mkcert -install
mkdir -p infra/local/certs
mkcert -cert-file infra/local/certs/localhost.pem \
  -key-file infra/local/certs/localhost-key.pem \
  localhost 127.0.0.1 ::1
```

The password prompt from `mkcert -install` expects your macOS login password.

## 2. Backend container

Create `enterprise-knowledge-assistant-backend/Dockerfile`:

```dockerfile
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY gradle gradle
COPY gradlew build.gradle settings.gradle ./
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon
COPY src src
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

Create `enterprise-knowledge-assistant-backend/.dockerignore`:

```text
.git
.gradle
build
.env
*.iml
.idea
```

> On Apple Silicon, the Compose file below uses `platform: linux/arm64`. If you receive `Exec format error`, run `docker compose build --no-cache backend`.

## 3. Frontend container

Create `enterprise-knowledge-assistant-frontend/Dockerfile`:

```dockerfile
FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
ARG VITE_API_BASE_URL=
ARG VITE_OIDC_AUTHORITY
ARG VITE_OIDC_CLIENT_ID=eka-frontend
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_OIDC_AUTHORITY=$VITE_OIDC_AUTHORITY
ENV VITE_OIDC_CLIENT_ID=$VITE_OIDC_CLIENT_ID
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

Create `enterprise-knowledge-assistant-frontend/nginx.conf`:

```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

The `try_files` line is needed so React can process `/auth/callback` after Keycloak sign-in.

Create `enterprise-knowledge-assistant-frontend/.dockerignore`:

```text
.git
node_modules
dist
.env
*.iml
.idea
```

## 4. Local passwords and Git safety

Create `infra/local/.env` and restrict access:

```bash
touch infra/local/.env
chmod 600 infra/local/.env
```

Add passwords:

```dotenv
POSTGRES_PASSWORD=replace-with-a-strong-local-database-password
KEYCLOAK_ADMIN_PASSWORD=replace-with-a-different-strong-local-admin-password
```

Create or update `infra/.gitignore`:

```gitignore
local/.env
local/certs/
```

Never commit passwords, certificates, access tokens, or callback URLs containing a `code` value.

## 5. Caddy reverse proxy

Create `infra/local/Caddyfile`:

```caddy
https://localhost:8443 {
    tls /certs/localhost.pem /certs/localhost-key.pem

    handle /api/* {
        reverse_proxy backend:8080
    }

    handle /actuator/health {
        reverse_proxy backend:8080
    }

    # Keep this before /auth/*.
    handle /auth/callback {
        reverse_proxy frontend:80
    }

    handle /auth {
        reverse_proxy keycloak:8080
    }

    handle /auth/* {
        reverse_proxy keycloak:8080
    }

    handle {
        reverse_proxy frontend:80
    }
}
```

Caddy runs in Docker. You do not need to install it on macOS.

## 6. Docker Compose

Create `infra/local/compose.yaml`:

```yaml
services:
  postgres:
    image: pgvector/pgvector:pg18
    environment:
      POSTGRES_DB: eka
      POSTGRES_USER: eka
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}
    volumes:
      # PostgreSQL 18+ uses this parent directory.
      - postgres_data:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U eka -d eka"]
      interval: 10s
      timeout: 5s
      retries: 10

  keycloak:
    image: quay.io/keycloak/keycloak:26.0
    command: start-dev
    environment:
      KC_BOOTSTRAP_ADMIN_USERNAME: admin
      KC_BOOTSTRAP_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD:?Set KEYCLOAK_ADMIN_PASSWORD in .env}
      KC_HTTP_ENABLED: "true"
      KC_HTTP_RELATIVE_PATH: /auth
      KC_PROXY_HEADERS: xforwarded
      KC_HOSTNAME: https://localhost:8443/auth
    depends_on:
      postgres:
        condition: service_healthy

  backend:
    platform: linux/arm64
    build:
      context: ../../enterprise-knowledge-assistant-backend
    environment:
      SPRING_PROFILES_ACTIVE: oidc
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/eka
      SPRING_DATASOURCE_USERNAME: eka
      SPRING_DATASOURCE_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}
      SPRING_FLYWAY_USER: eka
      SPRING_FLYWAY_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}
      SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: https://localhost:8443/auth/realms/eka
      SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI: http://keycloak:8080/auth/realms/eka/protocol/openid-connect/certs
      EKA_CRAG_ENABLED: "false"
      EKA_WEB_SEARCH_ENABLED: "false"
    depends_on:
      postgres:
        condition: service_healthy

  frontend:
    platform: linux/arm64
    build:
      context: ../../enterprise-knowledge-assistant-frontend
      args:
        VITE_API_BASE_URL: ""
        VITE_OIDC_AUTHORITY: https://localhost:8443/auth/realms/eka
        VITE_OIDC_CLIENT_ID: eka-frontend

  caddy:
    image: caddy:2.8-alpine
    ports:
      - "8443:8443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/certs:ro
    depends_on:
      - frontend
      - backend
      - keycloak

volumes:
  postgres_data:
```

Important:

- For PostgreSQL 18+, mount `/var/lib/postgresql`, not `/var/lib/postgresql/data`.
- The issuer is a browser address (`https://localhost:8443/...`).
- The JWKS address is Docker-internal (`http://keycloak:8080/...`), because a container cannot reach Caddy through its own `localhost`.

## 7. Start and verify

```bash
cd infra/local
docker compose config
docker compose up --build
```

`docker compose config` validates variables but may display resolved passwords. Do not share its output.

In another terminal:

```bash
curl https://localhost:8443/actuator/health
```

Expected response:

```json
{"groups":["liveness","readiness"],"status":"UP"}
```

## 8. Keycloak setup

1. Open `https://localhost:8443/auth/`.
2. Log in as `admin` with `KEYCLOAK_ADMIN_PASSWORD` from `.env`.
3. Create realm: `eka`.
4. In **eka**, select **Clients → Create client**.
5. Choose **OpenID Connect**; Client ID: `eka-frontend`.
6. Set:
   - Client authentication: **Off**
   - Authorization: **Off**
   - Standard flow: **On**
   - Direct access grants: **Off**
   - Service accounts roles: **Off**
7. Set login URLs:
   - Root URL: `https://localhost:8443`
   - Valid redirect URIs: `https://localhost:8443/auth/callback`
   - Valid post logout redirect URIs: `https://localhost:8443/login`
   - Web origins: `https://localhost:8443`
8. Save. Open **Advanced**, set PKCE challenge method to `S256`, then save.
9. Create a user under **Users**, set a password under **Credentials**, and turn **Temporary** off.

Verify this URL returns JSON:

```text
https://localhost:8443/auth/realms/eka/.well-known/openid-configuration
```

It must contain:

```json
{"issuer":"https://localhost:8443/auth/realms/eka"}
```

Do not configure a client secret. This is a public SPA using Authorization Code Flow with PKCE.

## 9. Create a collection and grant your SSO user access

After a user first signs in, EKA creates them as a `MEMBER` but gives no collection permissions. This is intentional.

Copy the UUID displayed as `Signed in as ...` in the app. This is the OIDC subject, not the Keycloak username.

Check existing collections:

```bash
docker compose exec postgres psql -U eka -d eka -c "SELECT id, name FROM collections;"
```

If no collection exists:

```bash
docker compose exec postgres psql -U eka -d eka -c \
"INSERT INTO collections (name, description)
 VALUES ('Local Knowledge Base', 'My local EKA documents');"
```

Grant upload and read access. Replace `<subject-uuid>`:

```bash
docker compose exec postgres psql -U eka -d eka -c \
"INSERT INTO collection_grants (subject, collection_id, permission)
 SELECT '<subject-uuid>', id, 'MANAGE'
 FROM collections
 WHERE name = 'Local Knowledge Base';"
```

Verify:

```bash
docker compose exec postgres psql -U eka -d eka -c \
"SELECT c.name, g.permission
 FROM collection_grants g
 JOIN collections c ON c.id = g.collection_id
 WHERE g.subject = '<subject-uuid>';"
```

Refresh the app or sign in again. `MANAGE` permits uploads and reads; `READ` is read-only.

## Troubleshooting

### Backend shows `Exec format error`

Confirm `platform: linux/arm64`, then:

```bash
docker compose build --no-cache backend
docker compose up -d backend
```

### `/auth/callback` returns 404

Confirm Caddy routes `/auth/callback` to `frontend:80` **before** `/auth/*`, and Nginx includes:

```nginx
try_files $uri $uri/ /index.html;
```

Then:

```bash
docker compose up -d --build frontend
docker compose restart caddy
```

### `/api/v1/me` returns `UNAUTHENTICATED` after SSO

Confirm these backend values:

```yaml
SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: https://localhost:8443/auth/realms/eka
SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI: http://keycloak:8080/auth/realms/eka/protocol/openid-connect/certs
```

Then recreate the backend:

```bash
docker compose up -d --force-recreate backend
docker compose logs -f backend
```

### Browser displays an old HTML response for an API request

Use an incognito/private window, or DevTools → Network → **Disable cache**, then hard reload.

### Reset a disposable local database

```bash
docker compose down -v
docker compose up --build
```

`-v` permanently deletes local database data, document metadata, and indexes.

## Useful commands

```bash
docker compose up --build                     # Start/rebuild all services
docker compose up -d --build                  # Start in background
docker compose ps                             # Show service status
docker compose logs -f backend                # Follow backend logs
docker compose logs -f caddy                  # Follow Caddy logs
docker compose up -d --force-recreate backend # Apply backend env changes
docker compose up -d --build frontend         # Rebuild after VITE_* or Nginx changes
docker compose down                           # Stop, retaining database data
docker compose down -v                        # Stop and delete local database data
```

## Why the frontend API base URL is empty

`VITE_API_BASE_URL: ""` means “use the same browser origin.” The request flow is:

```text
Browser → https://localhost:8443/api/v1/... → Caddy → backend:8080
```

This keeps browser traffic HTTPS, avoids CORS configuration, hides the backend port from macOS, and is similar to a real domain deployment. Vite embeds `VITE_*` variables at build time, so rebuild the frontend image after changing one.
