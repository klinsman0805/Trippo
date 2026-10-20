#!/usr/bin/env bash
#
# Deploy the API to Cloud Run in Singapore, next to the Supabase project.
#
#   PROJECT_ID=your-gcp-project \
#   SUPABASE_URL=https://YOUR-REF.supabase.co \
#   ./scripts/deploy-cloudrun.sh
#
# Safe to run again for every deploy: it creates what is missing and leaves
# what exists. Secrets are asked for once, typed at a hidden prompt, and kept
# in Secret Manager — never in a file, an argument or your shell history.
#
# Needs: gcloud (brew install --cask google-cloud-sdk), signed in with
# `gcloud auth login`, and a billing account on the project (Cloud Run's free
# tier still needs one on file — set a budget alert, see the README).
set -euo pipefail

: "${PROJECT_ID:?Set PROJECT_ID to your Google Cloud project id}"
: "${SUPABASE_URL:?Set SUPABASE_URL to https://YOUR-REF.supabase.co}"
REGION="${REGION:-asia-southeast1}"   # Singapore, as the Supabase project should be
SERVICE="${SERVICE:-trippo-api}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
gcloud config set project "$PROJECT_ID" >/dev/null

echo "→ turning on the services this needs (once; quick after that)"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com

# --- secrets ---

# ensure_secret NAME PROMPT required|optional
ensure_secret() {
  local name="$1" prompt="$2" need="$3" value
  if gcloud secrets describe "$name" >/dev/null 2>&1; then
    echo "→ secret $name: already set"
    return 0
  fi
  read -rsp "$prompt: " value
  echo
  if [ -z "$value" ]; then
    if [ "$need" = required ]; then
      echo "✗ $name is required." >&2
      exit 1
    fi
    echo "→ secret $name: skipped"
    return 0
  fi
  printf '%s' "$value" | gcloud secrets create "$name" --data-file=- --replication-policy=automatic >/dev/null
  echo "→ secret $name: stored"
}

ensure_secret trippo-database-url \
  "Supabase connection string (Connect → Transaction pooler, port 6543, password filled in)" required
ensure_secret trippo-gemini-key "Gemini API key" required
ensure_secret trippo-aerodatabox-key \
  "AeroDataBox key, for looking up booked flights by number (Enter to skip)" optional
ensure_secret trippo-google-maps-key \
  "Google Maps API key, for real venue names and published opening hours (Enter to skip)" optional

# Cloud Run runs as the project's default compute service account; it may
# read these secrets and nothing else in Secret Manager.
project_number="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
runtime_sa="${project_number}-compute@developer.gserviceaccount.com"

secrets="DATABASE_URL=trippo-database-url:latest,GEMINI_API_KEY=trippo-gemini-key:latest"
env_vars="SUPABASE_URL=${SUPABASE_URL}"
granted=(trippo-database-url trippo-gemini-key)
if gcloud secrets describe trippo-aerodatabox-key >/dev/null 2>&1; then
  secrets+=",AERODATABOX_API_KEY=trippo-aerodatabox-key:latest"
  env_vars+=",SCHEDULE_PROVIDER=aerodatabox"
  granted+=(trippo-aerodatabox-key)
fi
# Geocoding follows the key, the way the schedule provider follows its own.
#
# Photon is free and needs nothing, which is why it is the fallback — but it
# could not find six of nine Balik Pulau places and put three of the rest in
# George Town, 25km away. Places finds them, and publishes the opening hours
# the plan is checked against. It is billed per call, so it turns on only when
# the key is there to turn it on.
if gcloud secrets describe trippo-google-maps-key >/dev/null 2>&1; then
  secrets+=",GOOGLE_MAPS_API_KEY=trippo-google-maps-key:latest"
  env_vars+=",MAPS_PROVIDER=google"
  granted+=(trippo-google-maps-key)
else
  env_vars+=",MAPS_PROVIDER=osm"
fi
for name in "${granted[@]}"; do
  gcloud secrets add-iam-policy-binding "$name" \
    --member="serviceAccount:${runtime_sa}" \
    --role=roles/secretmanager.secretAccessor >/dev/null
done

# --- deploy ---

echo "→ building and deploying $SERVICE to $REGION (a few minutes)"
# --allow-unauthenticated: Cloud Run lets requests through to the server,
#   which turns away any without a valid Supabase token itself.
# --max-instances 2: a ceiling on what a traffic spike — or a loop — can cost.
# --timeout 600: longer than the planner's own 5-minute limit, so a slow plan
#   ends as a recorded failure the app can show, not a cut connection.
gcloud run deploy "$SERVICE" \
  --source "$root/server" \
  --region "$REGION" \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 2 \
  --concurrency 40 \
  --cpu 1 \
  --memory 512Mi \
  --timeout 600 \
  --set-env-vars "$env_vars" \
  --set-secrets "$secrets"

# Every deploy stores a new image, and Artifact Registry's free storage is
# 0.5 GB. Keep the last two (the running one and one to roll back to).
policy="$(mktemp)"
cat > "$policy" <<'JSON'
[
  { "name": "delete-old", "action": { "type": "Delete" }, "condition": { "tagState": "any" } },
  { "name": "keep-recent", "action": { "type": "Keep" }, "mostRecentVersions": { "keepCount": 2 } }
]
JSON
gcloud artifacts repositories set-cleanup-policies cloud-run-source-deploy \
  --location "$REGION" --policy "$policy" --no-dry-run >/dev/null
rm -f "$policy"

url="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
echo
echo "→ $url/health"
curl -fsS "$url/health" || true
echo
echo
echo "Deployed. Point the app at it:"
echo "  TRIPPO_API_BASE=$url SUPABASE_URL=$SUPABASE_URL SUPABASE_PUBLISHABLE_KEY=<your key> ./scripts/dev.sh"
