# --------------------------------
# Build arguments
# --------------------------------
ARG BACKEND_BRANCH=main
ARG FRONTEND_BRANCH=main

# --------------------------------
# Build the backend
# --------------------------------
FROM node:24-alpine AS backend-build
RUN apk add --no-cache git openssl
WORKDIR /build
RUN git clone https://github.com/musiclib/music-server.git music-server \
    && cd music-server \
    && if git ls-remote --exit-code --heads origin "$BACKEND_BRANCH" >/dev/null 2>&1; then \
         echo "Using backend branch: $BACKEND_BRANCH"; \
         git fetch origin "$BACKEND_BRANCH" \
         git checkout -B "$BACKEND_BRANCH" "origin/$BACKEND_BRANCH"; \
       else \
         echo "Backend branch '$BACKEND_BRANCH' does not exist; using main"; \
         git checkout main; \
       fi
WORKDIR /build/music-server
RUN npm ci
RUN npm run build
RUN npm prune --omit=dev
RUN cd certs \
    && openssl genrsa -out private.pem 4096 \
    && openssl rsa -in private.pem -pubout -out public.pem

# --------------------------------
# Build the frontend
# --------------------------------
FROM node:24-alpine AS frontend-build
RUN apk add --no-cache git
WORKDIR /build
RUN git clone https://github.com/musiclib/music-webui.git music-webui \
    && cd music-webui \
    && if git ls-remote --exit-code --heads origin "$FRONTEND_BRANCH" >/dev/null 2>&1; then \
         echo "Using frontend branch: $FRONTEND_BRANCH"; \
         git fetch origin "$FRONTEND_BRANCH" \
         git checkout -B "$FRONTEND_BRANCH" "origin/$FRONTEND_BRANCH"; \
       else \
         echo "Frontend branch '$FRONTEND_BRANCH' does not exist; using main"; \
         git checkout main; \
       fi
WORKDIR /build/music-webui
RUN npm ci
ENV NODE_ENV=production
ENV VITE_API_BASE_URL=/
RUN npm run build:prod


# --------------------------------
# Runtime image
# --------------------------------
FROM node:24-alpine
RUN apk add --no-cache nginx openssl
ENV NODE_ENV=production
WORKDIR /app/music-server
COPY --from=backend-build /build/music-server/package*.json ./
COPY --from=backend-build /build/music-server/node_modules ./node_modules
COPY --from=backend-build /build/music-server/dist ./dist
COPY --from=backend-build /build/music-server/certs ./certs
COPY --from=frontend-build \
    /build/music-webui/dist \
    /app/music-webui/dist
RUN mkdir -p /data /music /var/lib/nginx /var/log/nginx /run/nginx \
    && chown -R node:node /var/lib/nginx /var/log/nginx /run/nginx
RUN mkdir -p /data /library1 /library2 /library3 /library4 /library5 /library6 /library7 /library8 /library9 /library10 \
    && chown -R node:node /library1 /library2 /library3 /library4 /library5 /library6 /library7 /library8 /library9 /library10
RUN openssl rand -hex 32 > /app/.jwtsecret \
    && chown node:node /app/.jwtsecret \
    && chmod 600 /app/.jwtsecret
RUN cat <<'EOF' > /etc/nginx/nginx.conf
worker_processes 1;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /dev/stdout;
    error_log /dev/stderr;

    sendfile on;

    server {
        listen 8000;
        server_name _;

        root /app/music-webui/dist;
        index index.html;

        # Proxy API requests to the backend.
        location /api/ {
            proxy_pass http://127.0.0.1:7000;
            proxy_http_version 1.1;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Proxy Synology API requests to the backend.
        location /webapi/ {
            proxy_pass http://127.0.0.1:7000;
            proxy_http_version 1.1;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Support frontend client-side routing.
        location / {
            try_files $uri $uri/ /index.html;
        }
    }
}
EOF

RUN cat <<'EOF' > /usr/local/bin/start.sh
#!/bin/sh
set -eu
export JWT_SECRET="$(cat /app/.jwtsecret)"

# Start the API server.
node /app/music-server/dist/main.js &
backend_pid=$!

# Start nginx in the foreground.
nginx -g 'daemon off;' &
nginx_pid=$!

cleanup() {
    kill "$backend_pid" "$nginx_pid" 2>/dev/null || true
    wait "$backend_pid" "$nginx_pid" 2>/dev/null || true
}

trap cleanup TERM INT

# Exit if either process stops.
while kill -0 "$backend_pid" 2>/dev/null \
   && kill -0 "$nginx_pid" 2>/dev/null; do
    sleep 1
done

cleanup
EOF

RUN chmod +x /usr/local/bin/start.sh

USER node

VOLUME ["/data", "/music", "/library1", "/library2", "/library3", "/library4", "/library5", "/library6", "/library7", "/library8", "/library9", "/library10"]

ENV BUILD_DATABASE=true
ENV SERVER_PORT=7000
ENV SERVER_ADDRESS=127.0.0.1
ENV FRONTEND_PORT=8000
ENV FRONTEND_ADDRESS=127.0.0.1
ENV DATABASE_PATH=/data/music-server.sqlite

EXPOSE 8000

CMD ["/usr/local/bin/start.sh"]