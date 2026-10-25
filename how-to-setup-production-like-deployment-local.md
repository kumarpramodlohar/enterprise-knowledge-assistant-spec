How to setup production like deployment in a local mac os

Goal

Run locally at:

https://localhost:8443        → frontend

https://localhost:8443/api    → backend

https://localhost:8443/auth   → Keycloak

Use Docker Desktop on macOS.

Create local TLS certificate

Install mkcert, then create a certificate:

brew install mkcert

mkcert -install (may ask sudo password, put your mac login password than enter)

mkdir -p infra/local/certs

mkcert -cert-file infra/local/certs/localhost.pem \

-key-file infra/local/certs/localhost-key.pem \

localhost 127.0.0.1 ::1

2. Add backend Dockerfile

Create enterprise-knowledge-assistant-backend/Dockerfile:

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

Create enterprise-knowledge-assistant-backend/.dockerignore:

.git

.gradle

build

.env

*.iml

.idea

Add frontend Dockerfile

Create enterprise-knowledge-assistant-frontend/Dockerfile:

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

EXPOSE 80

Create enterprise-knowledge-assistant-frontend/.dockerignore:

.git

node_modules

dist

.env

*.iml

.idea

4. Create Caddy config

Create infra/local/Caddyfile:

https://localhost:8443 {

tls /certs/localhost.pem /certs/localhost-key.pem

handle /auth {

reverse_proxy keycloak:8080

}

handle /api/* {

reverse_proxy backend:8080

}

handle /auth/* {

reverse_proxy keycloak:8080

}

handle /actuator/health {

reverse_proxy backend:8080

}

handle {

reverse_proxy frontend:80

}

}

Note: You do not need to install Caddy on macOS.

Docker downloads and runs the Caddy container when you execute:

docker compose up --build

5. Create Compose file

Create infra/local/compose.yaml:

services:

postgres:

image: pgvector/pgvector:pg18

environment:

POSTGRES_DB: eka

POSTGRES_USER: eka

POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}

volumes:

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

Do not commit real passwords. Later, move them to .env.

1. Create the .env file

From infra/local:

touch .env

chmod 600 .env

POSTGRES_PASSWORD=<your password>

KEYCLOAK_ADMIN_PASSWORD=<your password>

chmod 600 means only your macOS user can read and write it.

2. Add local passwords

Open infra/local/.env and add:

POSTGRES_PASSWORD=choose-a-strong-local-postgres-password

KEYCLOAK_ADMIN_PASSWORD=choose-a-different-local-keycloak-password

For example, use a password manager to generate the real values. Do not copy those example values into a public repository.

3. Update compose.yaml

Replace hardcoded values:

POSTGRES_PASSWORD: change-this-local-password

with:

POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}

4. Prevent accidental Git commits

Create infra/.gitignore:

local/.env

local/certs/

Do not commit .env or the private certificate key.

5. Validate variables safely

From infra/local:

docker compose config  (very important command, here in a output you can see your real password which is you put inside the .env file variables)

This verifies that Compose can resolve the variables. Be careful: it can display resolved passwords in Terminal. Do not share or paste this output.

6. Start the stack

docker compose up --build

Below notes are self understanding you can skip this:

ARG VITE_API_BASE_URL= declares a Docker build-time variable with an empty default value.

This line in your Compose file supplies the value:

frontend:

build:

context: ../../enterprise-knowledge-assistant-frontend

args:

VITE_API_BASE_URL: ""

Docker flow:

compose.yaml build.args

→ Docker ARG VITE_API_BASE_URL

→ Docker ENV VITE_API_BASE_URL

→ npm run build

→ Vite embeds the value into the compiled frontend files

So the effective value is empty:

VITE_API_BASE_URL=""

Your frontend code interprets an empty API base URL as same-origin. The browser calls:

/api/v1/chat/query

instead of:

http://localhost:8080/api/v1/chat/query

Then Caddy receives the request at:

https://localhost:8443/api/v1/chat/query

and proxies it to the backend container:

backend:8080

This is the preferred local-production setup because:

•Browser traffic stays HTTPS.

•No browser CORS configuration is required.

•The backend is not exposed directly to your Mac network.

•You can later use the same pattern with a real domain.

Important: Vite reads VITE_* values during npm run build, not when the Nginx container

starts. To change a frontend variable, rebuild the frontend image:

docker compose up --build frontend

6. Start it

From infra/local:

docker compose up --build

Check:

curl -k https://localhost:8443/actuator/health

Expected:

{"status":"UP"}

Configure Keycloak

Open: https://localhost:8443/auth

1.Log in with the Keycloak bootstrap admin.

2.Create realm: eka

3.Create client: eka-frontend

4.Set client type: public

5.Enable Authorization Code Flow.

6.Enable PKCE with S256.

7. Set valid redirect URI: https://localhost:8443/auth/callback

Set post-logout redirect URI: https://localhost:8443/login

Create a test user and password.

8. Verify manually

1.Open https://localhost:8443

2.Click SSO sign-in.

3.Log in through Keycloak.

4.Confirm browser returns to the app.

5.Upload a non-sensitive PDF.

6.Wait for indexing.

7.Ask a question.

8.Confirm citations display.

9. Stop and reset

Stop containers: docker compose down

Delete local database completely: docker compose down -v

Only use -v when you intentionally want to delete all local uploaded/indexed database data.

# Keycloak Setup Guide for EKA

This guide documents the configuration shown in the supplied screenshots.

## 1. Log in to Keycloak Admin

Use the admin console credentials:

Username: admin

Password: The value of KEYCLOAK_ADMIN_PASSWORD in infra/local/.env

## 2. Create a Realm

Open the realm dropdown in the top-left corner.

Select Create realm.

Set the realm name to eka.

Click Create.

## 3. Create an OIDC Client

Inside the eka realm:

Navigate to Clients → Create client.

Set Client type to OpenID Connect.

Set Client ID to eka-frontend.

Click Next.

Configure client capabilities:

Client authentication: Off

Authorization: Off

Standard flow: On

Direct access grants: Off

Service accounts roles: Off

Click Next.

Configure login settings:

Root URL: https://localhost:8443

Valid redirect URIs: https://localhost:8443/auth/callback

Valid post logout redirect URIs: https://localhost:8443/login

Web origins: https://localhost:8443

Click Save.

## 4. Configure PKCE

Navigate to Clients → eka-frontend → Advanced.

Set Proof Key for Code Exchange Code Challenge Method to S256.

Click Save.

## 5. Create a Test User

Navigate to Users → Add user.

Set:

Username: eka-demo-user

Email verified: On

Enabled: On

Click Create.

Open Credentials.

Click Set password and choose a test password.

Set Temporary to Off.

Save.

## 6. Verify the Realm Discovery URL

Open:

https://localhost:8443/auth/realms/eka/.well-known/openid-configuration

The returned JSON should include an issuer like:

{

"issuer": "https://localhost:8443/auth/realms/eka"}

## Notes

Do not configure a client secret. This is a browser-based single-page application (SPA) using the Authorization Code Flow with PKCE.

These URLs assume Keycloak is exposed locally at https://localhost:8443.

Keep the admin password and test-user password private; do not commit secrets to source control.
