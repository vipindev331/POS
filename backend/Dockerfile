# POS backend — production image.
FROM node:22-slim AS base
WORKDIR /app

# better-sqlite3 needs a toolchain to build its native addon.
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY . .

# Persist the SQLite database on a mounted volume.
ENV NODE_ENV=production
ENV DB_PATH=/data/pos.sqlite
VOLUME ["/data"]
EXPOSE 4000

# Apply schema + seed on first boot, then start.
CMD ["sh", "-c", "node scripts/setup.js && node src/server.js"]
