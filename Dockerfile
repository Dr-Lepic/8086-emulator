# ============================================================
# Stage 1: Compile Rust → WASM
# ============================================================
FROM rust:1.85-slim AS rust-wasm

RUN apt-get update && apt-get install -y curl pkg-config libssl-dev && \
    curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy Rust project files
COPY Cargo.toml ./
COPY .cargo ./.cargo
COPY src ./src

# Build WASM package
RUN wasm-pack build --target bundler

# ============================================================
# Stage 2: Build React frontend
# ============================================================
FROM node:18-alpine AS node-build

WORKDIR /app

# Copy generated WASM package from stage 1
COPY --from=rust-wasm /build/pkg /app/pkg

# Copy webapp files
COPY webapp/package.json webapp/package-lock.json ./webapp/
WORKDIR /app/webapp

# Install dependencies
RUN npm ci --legacy-peer-deps

# Copy rest of webapp source
COPY webapp/ ./

# Build with PUBLIC_URL set to / for local Docker usage
ENV PUBLIC_URL=/
ENV NODE_OPTIONS=--openssl-legacy-provider
RUN npm run build

# ============================================================
# Stage 3: Serve with nginx
# ============================================================
FROM nginx:alpine AS serve

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built static files
COPY --from=node-build /app/webapp/build /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
