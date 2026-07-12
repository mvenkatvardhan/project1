# ---------- Stage 1: build/install dependencies ----------
FROM node:20-alpine AS builder
RUN apk update && apk upgrade --no-cache
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src

# ---------- Stage 2: minimal runtime image ----------
FROM node:20-alpine AS runtime
RUN apk update && apk upgrade --no-cache
# Run as non-root user (reduces attack surface, flagged by security scanners if skipped)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY package*.json ./

ENV NODE_ENV=production
ENV PORT=3000

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

CMD ["node", "src/app.js"]
