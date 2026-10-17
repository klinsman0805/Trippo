# The API server, as Cloud Run runs it. Build context: this folder.
#
#   gcloud run deploy --source server   (see scripts/deploy-cloudrun.sh)

FROM node:22-bookworm AS build
WORKDIR /srv
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

FROM node:22-bookworm-slim
WORKDIR /srv
ENV NODE_ENV=production \
    HOST=0.0.0.0
COPY --from=build /srv/package.json ./
COPY --from=build /srv/node_modules ./node_modules
COPY --from=build /srv/dist ./dist
# Not root: nothing here needs it, and a compromised process should not have it.
USER node
# Cloud Run sets PORT; the server reads it.
CMD ["node", "dist/index.js"]
