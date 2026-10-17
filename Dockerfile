# One image that serves both halves: the API under /v1, and the Flutter web
# app at /. It exists so the app can be tried from a phone browser with no
# computer involved — open one address, everything is there.
#
# Local development does not use this; see scripts/dev.sh.

# --- the web app ---
# The full Node image, for the tools Flutter needs (curl, git, unzip, xz) —
# already present, so nothing is installed with apt, and the layer is shared
# with the server stage below.
FROM node:22-bookworm AS web

# The same Flutter as local development, so a web build here behaves like the
# app on a desk. Bump with the local SDK, not independently of it.
ARG FLUTTER_VERSION=3.47.7

RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
  | tar -xJ -C /opt
ENV PATH=/opt/flutter/bin:$PATH
RUN git config --global --add safe.directory /opt/flutter \
  && flutter --disable-analytics \
  && flutter precache --web

WORKDIR /src/app
# Dependencies before sources, so editing a screen does not re-fetch packages.
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get
COPY app/ ./
# `same-origin`: the API is wherever the page came from (see AppConfig).
# `--no-web-resources-cdn`: the rendering engine is served from here too,
# rather than fetched from Google's CDN on every load — one less thing that
# has to be reachable for the app to draw at all.
RUN flutter build web --release --no-web-resources-cdn \
  --dart-define=TRIPPO_API_BASE=same-origin

# --- the server ---
# The full image, not slim: better-sqlite3 falls back to compiling itself when
# no prebuilt binary matches, and that needs the toolchain slim leaves out.
FROM node:22-bookworm AS server
WORKDIR /src/server
COPY server/package.json server/package-lock.json ./
RUN npm ci
COPY server/ ./
RUN npm run build && npm prune --omit=dev

# --- what runs ---
FROM node:22-bookworm-slim
WORKDIR /srv/server
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    WEB_DIR=/srv/web \
    DATABASE_PATH=/srv/data/trippo.db
COPY --from=server /src/server/package.json ./
COPY --from=server /src/server/node_modules ./node_modules
COPY --from=server /src/server/dist ./dist
COPY --from=web /src/app/build/web /srv/web
# PORT comes from the host (Render sets it); the server reads it from env.
CMD ["node", "dist/index.js"]
