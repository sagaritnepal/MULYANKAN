# syntax=docker/dockerfile:1
#
# Railway builds from the repo root (the CLI uploads the linked project
# root, not the current directory), so this Dockerfile reaches down into
# backend/ rather than living beside it.

# ---- builder: full deps, generate Prisma client, compile TS ----
FROM node:22-slim AS builder

# Prisma's query engine needs OpenSSL at generate time.
RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY backend/package.json backend/package-lock.json ./
RUN npm ci

COPY backend/prisma ./prisma
RUN npx prisma generate

COPY backend/tsconfig.json backend/nest-cli.json ./
COPY backend/src ./src
RUN npm run build

# ---- runner: production deps only ----
FROM node:22-slim AS runner

RUN apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV NODE_ENV=production

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# The generated client lives outside the dependency tree, so it is copied
# from the builder rather than regenerated (the prisma CLI is a devDependency).
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./node_modules/@prisma/client

COPY --from=builder /app/dist ./dist
COPY backend/prisma ./prisma

# Railway injects PORT; main.ts falls back to 3000 locally.
EXPOSE 3000
CMD ["node", "dist/main.js"]
