# Backend image — small, production-only deps.
FROM node:24-alpine

WORKDIR /app

# Install deps first (layer-cached until the lockfile changes).
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Then the source.
COPY src ./src

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

# Run as the built-in non-root user.
USER node

CMD ["node", "src/server.js"]
