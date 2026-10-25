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
## Docker Desktop Kubernetes local setup

This section runs EKA on Docker Desktop Kubernetes after the Docker Compose setup is understood.

> This is still a local development environment. It is not a production Kubernetes configuration. Keycloak uses `start-dev`, secrets are local Kubernetes secrets, and PostgreSQL runs inside the cluster.

### Kubernetes local URLs

| URL | Service |
| --- | --- |
| `http://localhost` | React frontend through Ingress |
| `http://localhost/api/...` | Spring Boot backend through Ingress |
| `http://localhost/auth/` | Keycloak through Ingress |
| `http://localhost/actuator/health` | Backend health check through Ingress |

The Kubernetes local setup starts with HTTP to reduce TLS complexity. HTTPS can be added later with a Kubernetes TLS secret and Ingress TLS configuration.

### Docker Desktop Kubernetes note

Docker Desktop Kubernetes is normally a single-node local cluster.

That is sufficient for:

- testing Kubernetes manifests,
- running EKA locally,
- testing Services,
- testing Ingress,
- testing Keycloak login flow,
- testing backend/frontend/database integration.

A separate tool such as `kind` is only needed if you specifically want a multi-node local cluster, for example one control-plane node and two worker nodes.

For this Docker Desktop Kubernetes setup, `kind` is not required.

### 10. Enable Docker Desktop Kubernetes

Open Docker Desktop:
Docker Desktop → Settings → Kubernetes → Enable Kubernetes

Apply the change and wait until Kubernetes is running.

Verify:

```bash
kubectl config current-context
kubectl get nodes
```
Expected current context:

```text
docker-desktop
```

Expected node output is usually similar to:

```text
desktop-control-plane Ready
```

### 11. Create Kubernetes manifest directory

Run from the parent `EnterpriseKnowledgeAssitance` directory:

```bash
mkdir -p infra/k8s/local
```

Suggested structure:

```text
infra/ └── k8s/ └── local/ ├── namespace.yaml ├── configmap.yaml ├── postgres.yaml ├── keycloak.yaml ├── backend.yaml ├── frontend.yaml └── ingress.yaml
```

### 12. Create namespace

Create `infra/k8s/local/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: eka
```

Apply it:

```bash
kubectl apply -f infra/k8s/local/namespace.yaml
```

Verify:

```bash
kubectl get namespaces
```

### 13. Create Kubernetes secret

Create the local Kubernetes secret:

```bash
kubectl create secret generic eka-secrets
--namespace eka
--from-literal=POSTGRES_PASSWORD='replace-with-a-strong-local-database-password'
--from-literal=KEYCLOAK_ADMIN_PASSWORD='replace-with-a-different-strong-local-admin-password'
```

Verify:

```bash
kubectl get secret eka-secrets -n eka
```

Do not commit real passwords to Git.

To update the secret later:

```bash
kubectl create secret generic eka-secrets
--namespace eka
--from-literal=POSTGRES_PASSWORD='replace-with-new-local-database-password'
--from-literal=KEYCLOAK_ADMIN_PASSWORD='replace-with-new-local-keycloak-password'
--dry-run=client
-o yaml | kubectl apply -f -
```

If the output is:

```text
secret/eka-secrets unchanged
```

then Kubernetes detected no effective value change.

Pods do not automatically reload environment variables from updated secrets. Restart affected workloads after a secret change:

```bash
kubectl rollout restart deployment/backend -n eka
kubectl rollout restart deployment/keycloak -n eka
```

If the PostgreSQL password changes after PostgreSQL has already initialized its data volume, changing the Kubernetes secret alone does not change the actual database user password. For a disposable local setup, delete and recreate the namespace. For a retained database, update the password inside PostgreSQL as well.

### 14. Create ConfigMap

Create `infra/k8s/local/configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: eka-config
  namespace: eka
data:
  POSTGRES_DB: eka
  POSTGRES_USER: eka
  SPRING_PROFILES_ACTIVE: oidc
  SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/eka
  SPRING_DATASOURCE_USERNAME: eka
  SPRING_FLYWAY_USER: eka
  SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: http://localhost/auth/realms/eka
  SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI: http://keycloak:8080/auth/realms/eka/protocol/openid-connect/certs
  EKA_CRAG_ENABLED: "false"
  EKA_WEB_SEARCH_ENABLED: "false"
  EKA_WEB_SEARCH_TIMEOUT: "10s"
```

Apply it:

```bash
kubectl apply -f infra/k8s/local/configmap.yaml
```

Important:

- The issuer URI is the browser-facing URL: `http://localhost/auth/realms/eka`.
- The JWKS URI is the cluster-internal URL: `http://keycloak:8080/auth/realms/eka/protocol/openid-connect/certs`.

### 15. Create PostgreSQL manifest

Create `infra/k8s/local/postgres.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: eka
spec:
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
  selector:
    app: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: eka
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: pgvector/pgvector:pg18
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: POSTGRES_DB
            - name: POSTGRES_USER
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: POSTGRES_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: eka-secrets
                  key: POSTGRES_PASSWORD
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql
          readinessProbe:
            exec:
              command:
                - sh
                - -c
                - pg_isready -U eka -d eka
            initialDelaySeconds: 10
            periodSeconds: 10
  volumeClaimTemplates:
    - metadata:
        name: postgres-storage
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 5Gi
```

Apply it:

```bash
kubectl apply -f infra/k8s/local/postgres.yaml
```

Verify:

```bash
kubectl get pods -n eka -w
```

### 16. Create Keycloak manifest

Create `infra/k8s/local/keycloak.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: eka
spec:
  ports:
    - name: http
      port: 8080
      targetPort: 8080
  selector:
    app: keycloak
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: eka
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:26.0
          args:
            - start-dev
          ports:
            - containerPort: 8080
          env:
            - name: KC_BOOTSTRAP_ADMIN_USERNAME
              value: admin
            - name: KC_BOOTSTRAP_ADMIN_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: eka-secrets
                  key: KEYCLOAK_ADMIN_PASSWORD
            - name: KC_HTTP_ENABLED
              value: "true"
            - name: KC_HTTP_RELATIVE_PATH
              value: /auth
            - name: KC_PROXY_HEADERS
              value: xforwarded
            - name: KC_HOSTNAME
              value: http://localhost/auth
```

Apply it:

```bash
kubectl apply -f infra/k8s/local/keycloak.yaml
```

### 17. Build backend and frontend images

Run from the parent `EnterpriseKnowledgeAssitance` directory.

Build backend:

```bash
docker build -t eka-backend:local ./enterprise-knowledge-assistant-backend
```

Build frontend:

```bash
docker build
-t eka-frontend:local
--build-arg VITE_API_BASE_URL=""
--build-arg VITE_OIDC_AUTHORITY="http://localhost/auth/realms/eka"
--build-arg VITE_OIDC_CLIENT_ID="eka-frontend"
./enterprise-knowledge-assistant-frontend
```

Verify:

```bash
docker images | grep eka
```

Expected:

```text
eka-backend local eka-frontend local
```

### 18. Import local images into Docker Desktop Kubernetes node

Docker Desktop Kubernetes may not see images from the normal Docker image store when deployments use `imagePullPolicy: Never`.

Import the images into the Kubernetes node runtime:

```bash
docker save eka-backend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import -
docker save eka-frontend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import -
```

Verify inside the Kubernetes node:

```bash
docker exec -it desktop-control-plane ctr -n k8s.io images list | grep eka
```

Expected image names include:

```text
docker.io/library/eka-backend:local docker.io/library/eka-frontend:local
```

### 19. Create backend manifest

Create `infra/k8s/local/backend.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: eka
spec:
  ports:
    - name: http
      port: 8080
      targetPort: 8080
  selector:
    app: backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: eka
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: eka-backend:local
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_PROFILES_ACTIVE
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: SPRING_PROFILES_ACTIVE
            - name: SPRING_DATASOURCE_URL
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: SPRING_DATASOURCE_URL
            - name: SPRING_DATASOURCE_USERNAME
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: SPRING_DATASOURCE_USERNAME
            - name: SPRING_DATASOURCE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: eka-secrets
                  key: POSTGRES_PASSWORD
            - name: SPRING_FLYWAY_USER
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: SPRING_FLYWAY_USER
            - name: SPRING_FLYWAY_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: eka-secrets
                  key: POSTGRES_PASSWORD
            - name: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI
            - name: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI
            - name: EKA_CRAG_ENABLED
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: EKA_CRAG_ENABLED
            - name: EKA_WEB_SEARCH_ENABLED
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: EKA_WEB_SEARCH_ENABLED
            - name: EKA_WEB_SEARCH_TIMEOUT
              valueFrom:
                configMapKeyRef:
                  name: eka-config
                  key: EKA_WEB_SEARCH_TIMEOUT
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /actuator/health
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 30
```

Apply it:

```bash
kubectl apply -f infra/k8s/local/backend.yaml
```

### 20. Create frontend manifest

Create `infra/k8s/local/frontend.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: eka
spec:
  ports:
    - name: http
      port: 80
      targetPort: 80
  selector:
    app: frontend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: eka
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: eka-frontend:local
          imagePullPolicy: Never
          ports:
            - containerPort: 80
```

Apply it:

```bash
kubectl apply -f infra/k8s/local/frontend.yaml
```

Verify pods:

```bash
kubectl get pods -n eka -w
```

Expected:

```text
backend-... 1/1 Running frontend-... 1/1 Running keycloak-... 1/1 Running postgres-0 1/1 Running
```

### 21. Install NGINX Ingress Controller

Install the Docker Desktop compatible NGINX Ingress Controller:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
```

Wait for the controller:

```bash
kubectl get pods -n ingress-nginx -w
```

### 22. Create Ingress

Create `infra/k8s/local/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: eka-ingress
  namespace: eka
spec:
  ingressClassName: nginx
  rules:
    - host: localhost
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 8080
          - path: /actuator/health
            pathType: Exact
            backend:
              service:
                name: backend
                port:
                  number: 8080
          - path: /auth/callback
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
          - path: /auth
            pathType: Prefix
            backend:
              service:
                name: keycloak
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```

Apply it:

```bash
kubectl apply -f infra/k8s/local/ingress.yaml
```

Verify:

```bash
kubectl get ingress -n eka
kubectl describe ingress eka-ingress -n eka
```

Test backend health through Ingress:

```bash
curl http://localhost/actuator/health
```

Expected:

```json
{"groups":["liveness","readiness"],"status":"UP"}
```

Open the frontend:

```text
http://localhost
```

Open Keycloak:

```text
http://localhost/auth/
```

### 23. Configure Keycloak for Kubernetes local setup

Open:

```text
http://localhost/auth/
```

Log in as `admin` using the local `KEYCLOAK_ADMIN_PASSWORD`.

Create realm:

```text
eka
```

Create OIDC client:

```text
Client ID: eka-frontend Client type: OpenID Connect
```

Set:

```text
Client authentication: Off Authorization: Off Standard flow: On Direct access grants: Off Service accounts roles: Off
```

Set login URLs:

```text
Root URL: http://localhost Valid redirect URIs: http://localhost/auth/callback Valid post logout redirect URIs: http://localhost/login Web origins: http://localhost
```

Open the client Advanced settings and set:

```text
PKCE challenge method: S256
```

Create a user, set a password, and turn Temporary off.

Verify OIDC discovery:

```bash
curl http://localhost/auth/realms/eka/.well-known/openid-configuration
```

It must contain:

```json
{"issuer":"http://localhost/auth/realms/eka"}
```

### 24. Create a collection and grant your SSO user access in Kubernetes

After the user first signs in, EKA creates them as a `MEMBER` but gives no collection permissions.

Copy the UUID displayed as `Signed in as ...` in the app. This is the OIDC subject, not the Keycloak username.

Open PostgreSQL shell:

```bash
kubectl exec -it -n eka statefulset/postgres -- psql -U eka -d eka
```

Check collections:

```sql
SELECT id, name FROM collections;
```

If no collection exists:

```sql
INSERT INTO collections (name, description) VALUES ('Local Knowledge Base', 'My local EKA documents');
```

Grant upload and read access. Replace `<subject-uuid>`:

```sql
INSERT INTO collection_grants (subject, collection_id, permission) SELECT '<subject-uuid>', id, 'MANAGE' FROM collections WHERE name = 'Local Knowledge Base';
```

Verify:

```sql
SELECT c.name, g.permission FROM collection_grants g JOIN collections c ON c.id = g.collection_id WHERE g.subject = '<subject-uuid>';
```

Exit:

```sql
\q
```

Refresh the app or sign in again. `MANAGE` permits uploads and reads; `READ` is read-only.

## Kubernetes troubleshooting

### Pods show `ErrImageNeverPull`

Symptom:

```text
backend-... 0/1 ErrImageNeverPull frontend-... 0/1 ErrImageNeverPull
```

Check pod details:

```bash
kubectl describe pod <pod-name> -n eka
```

Typical event:

```text
Container image "eka-backend:local" is not present with pull policy of Never
```

Reason:

- The deployment uses `imagePullPolicy: Never`.
- Kubernetes will not pull the image from a registry.
- Docker Desktop Kubernetes may not see images from the normal Docker image store.
- The image must exist inside the Kubernetes node runtime.

Solution:

```bash
docker build -t eka-backend:local ./enterprise-knowledge-assistant-backend
docker save eka-backend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import - kubectl rollout restart deployment/backend -n eka
```

For frontend:

```bash
docker build
-t eka-frontend:local
--build-arg VITE_API_BASE_URL=""
--build-arg VITE_OIDC_AUTHORITY="http://localhost/auth/realms/eka"
--build-arg VITE_OIDC_CLIENT_ID="eka-frontend"
./enterprise-knowledge-assistant-frontend
docker save eka-frontend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import - kubectl rollout restart deployment/frontend -n eka
```

Verify:

```bash
kubectl get pods -n eka -w
```

Expected:

```text
backend-... 1/1 Running frontend-... 1/1 Running keycloak-... 1/1 Running postgres-0 1/1 Running
```

### `kind: command not found`

Symptom:

```text
zsh: command not found: kind
```

Reason:

The `kind` CLI is not installed.

Solution:

For the Docker Desktop Kubernetes setup, no action is required. `kind` is not needed.

Only install `kind` if you specifically want a separate multi-node local Kubernetes cluster:

```bash
brew install kind
```

For this Docker Desktop setup, use:

```bash
docker save eka-backend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import -
docker save eka-frontend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import -
```

instead of:

```bash
kind load docker-image ...
```

### `secret/eka-secrets unchanged`

Symptom:

```text
secret/eka-secrets unchanged
```

Reason:

Kubernetes compared the new generated Secret manifest with the existing `eka-secrets` Secret and detected no effective change.

Solution:

Verify the current decoded value carefully:

```bash
kubectl get secret eka-secrets -n eka
-o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode echo
bash kubectl get secret eka-secrets -n eka
-o jsonpath='{.data.KEYCLOAK_ADMIN_PASSWORD}' | base64 --decode echo
```

If the values are already correct, no change is needed.

If you changed secret values, restart affected pods:

```bash
kubectl rollout restart deployment/backend -n eka
kubectl rollout restart deployment/keycloak -n eka
```

### PostgreSQL password changed but backend cannot connect

Reason:

Changing the Kubernetes Secret does not automatically update the password stored inside an already-initialized PostgreSQL data volume.

For a disposable local environment, reset the namespace:

```bash
kubectl delete namespace eka
```

Then recreate the namespace, secret, config, and workloads.

If you want to keep the existing database, update the PostgreSQL user password manually:

```bash
kubectl exec -it -n eka statefulset/postgres -- psql -U eka -d eka
```

Then run:

```sql
ALTER USER eka WITH PASSWORD 'replace-with-new-local-database-password';
```

Exit:

```sql
\q
```

Restart backend:

```bash
kubectl rollout restart deployment/backend -n eka
```

### Backend or frontend image was rebuilt but app still behaves like the old version

Reason:

For Docker Desktop Kubernetes with `imagePullPolicy: Never`, rebuilding the Docker image is not enough. The image must also be imported into the Kubernetes node runtime, and the deployment must be restarted.

Solution:

Backend:

```bash
docker build -t eka-backend:local ./enterprise-knowledge-assistant-backend
docker save eka-backend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import - kubectl rollout restart deployment/backend -n eka
```

Frontend:

```bash
docker build
-t eka-frontend:local
--build-arg VITE_API_BASE_URL=""
--build-arg VITE_OIDC_AUTHORITY="http://localhost/auth/realms/eka"
--build-arg VITE_OIDC_CLIENT_ID="eka-frontend"
./enterprise-knowledge-assistant-frontend
docker save eka-frontend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import - kubectl rollout restart deployment/frontend -n eka
```

### `/auth/callback` returns 404 in Kubernetes

Reason:

The Ingress must route `/auth/callback` to the frontend before routing `/auth` to Keycloak. The React app must handle the callback route.

Solution:

Confirm the Ingress contains `/auth/callback` routed to the frontend service and `/auth` routed to the Keycloak service.

Also confirm the frontend Nginx configuration contains:

```nginx
try_files uriuri/ /index.html;
```

Rebuild and re-import frontend after changing Nginx or Vite values:

```bash
docker build
-t eka-frontend:local
--build-arg VITE_API_BASE_URL=""
--build-arg VITE_OIDC_AUTHORITY="http://localhost/auth/realms/eka"
--build-arg VITE_OIDC_CLIENT_ID="eka-frontend"
./enterprise-knowledge-assistant-frontend
docker save eka-frontend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import - kubectl rollout restart deployment/frontend -n eka
```

### `/api/v1/me` returns `UNAUTHENTICATED` after SSO in Kubernetes

Reason:

The issuer URI or JWKS URI may not match the Kubernetes local Keycloak setup.

Confirm these backend environment values:

```text
SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI=http://localhost/auth/realms/eka SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI=http://keycloak:8080/auth/realms/eka/protocol/openid-connect/certs
```

Verify OIDC discovery:

```bash
curl http://localhost/auth/realms/eka/.well-known/openid-configuration
```

The issuer must be:

```json
{"issuer":"http://localhost/auth/realms/eka"}
```

Restart backend after config changes:

```bash
kubectl rollout restart deployment/backend -n eka
```

### Ingress does not respond at `http://localhost`

Check Ingress Controller pods:

```bash
kubectl get pods -n ingress-nginx
```

Check EKA Ingress:

```bash
kubectl get ingress -n eka
kubectl describe ingress eka-ingress -n eka
```

Check services:

```bash
kubectl get svc -n eka
```

If needed, verify services directly with port-forward.

Backend:

```bash
kubectl port-forward -n eka service/backend 8080:8080
```

Then:

```bash
curl http://localhost:8080/actuator/health
```

Frontend:

```bash
kubectl port-forward -n eka service/frontend 3000:80
```

Then open:

```text
http://localhost:3000
```

Keycloak:

```bash
kubectl port-forward -n eka service/keycloak 8081:8080
```

Then open:

```text
http://localhost:8081/auth/
```

## Kubernetes useful commands

```bash
kubectl get all -n eka
kubectl get pods -n eka -w
kubectl get svc -n eka
kubectl get ingress -n eka
kubectl logs -n eka deployment/backend -f
kubectl logs -n eka deployment/frontend -f
kubectl logs -n eka deployment/keycloak -f
kubectl logs -n eka statefulset/postgres -f
kubectl describe pod <pod-name> -n eka
kubectl rollout restart deployment/backend -n eka
kubectl rollout restart deployment/frontend -n eka
kubectl rollout restart deployment/keycloak -n eka
kubectl delete namespace eka
```

## Why Docker Desktop Kubernetes needs image import

With Docker Compose, containers are started by Docker directly from images in the normal Docker image store.

With Docker Desktop Kubernetes, the Kubernetes node uses a container runtime inside the Kubernetes node. When a Deployment uses:

```yaml
imagePullPolicy: Never
```

Kubernetes only starts the pod if the image already exists inside that node runtime.

That is why this may fail:

```bash
docker build -t eka-backend:local ./enterprise-knowledge-assistant-backend kubectl rollout restart deployment/backend -n eka
```

with:

```text
ErrImageNeverPull
```

The fix is to import the built image into the Kubernetes node runtime:

```bash
docker save eka-backend:local | docker exec -i desktop-control-plane ctr -n k8s.io images import -
```

Then restart the deployment:

```bash
kubectl rollout restart deployment/backend -n eka
```

## When to use kind

`kind` is not required for Docker Desktop Kubernetes.

Use `kind` only if you want to create a separate local multi-node Kubernetes cluster. For example:

- one control-plane node,
- two worker nodes,
- scheduling behavior closer to cloud Kubernetes.

For the current local EKA Kubernetes setup, Docker Desktop Kubernetes is enough.
