#!/usr/bin/env bash
set -e

STEP_CNT=5

echo_step() {
cat <<EOF

######################################################################

Init Step ${1}/${STEP_CNT} [${2}] -- ${3}

######################################################################

EOF
}

# ───────────────────────────────────────────────────────────────────
# Step 1: Database migrations
# ───────────────────────────────────────────────────────────────────
echo_step "1" "Starting" "Applying DB migrations"
sleep 10
superset db upgrade
echo_step "1" "Complete" "Applying DB migrations"

# ───────────────────────────────────────────────────────────────────
# Step 2: Admin user
# ───────────────────────────────────────────────────────────────────
ADMIN_PASSWORD="${SUPERSET_ADMIN_PASSWORD:-admin}"

echo_step "2" "Starting" "Setting up admin user"
superset fab create-admin \
    --username admin \
    --email admin@superset.local \
    --password "${ADMIN_PASSWORD}" \
    --firstname Superset \
    --lastname Admin || true
echo_step "2" "Complete" "Setting up admin user"

# ───────────────────────────────────────────────────────────────────
# Step 3: Roles and permissions
# ───────────────────────────────────────────────────────────────────
echo_step "3" "Starting" "Setting up roles and perms"
superset init
echo_step "3" "Complete" "Setting up roles and perms"

# ───────────────────────────────────────────────────────────────────
# Step 4: Trino connection to Bitrix24 portal
# ───────────────────────────────────────────────────────────────────
echo_step "4" "Starting" "Creating trino connection to B24 portal"

BX_PORTAL_URL="${BX_PORTAL_URL:?BX_PORTAL_URL is required}"
# Trino connection goes through nginx SSL proxy in runtime.
# During init we also register via nginx so the saved URI works at runtime.
TRINO_HOST="${TRINO_HOST:-nginx}"
TRINO_PORT="${TRINO_PORT:-443}"
TRINO_SCHEME="${TRINO_SCHEME:-https}"

# URL-encode session_properties JSON
SESSION_PROPS=$(python3 -c "
from urllib.parse import quote
import json
props = json.dumps({
    'bi.server_url': '${BX_PORTAL_URL}',
    'bi.secret_key': 'demo_key'
})
print(quote(props))
")

TRINO_URI="trino://client:${TRINO_CLIENT_KEY}@${TRINO_HOST}:${TRINO_PORT}/bi?http_scheme=${TRINO_SCHEME}&session_properties=${SESSION_PROPS}&source=client&verify=false"

if [[ $(superset does-database-exist -d trino) == *"Y"* ]]; then
  echo "Database trino already exists"
else
  echo "Adding trino database connection"
  superset set-database-uri \
    --database_name 'trino' \
    --uri "${TRINO_URI}"
fi

echo_step "4" "Completed" "Creating trino connection to B24 portal"

# ───────────────────────────────────────────────────────────────────
# Step 5: Bitrix roles
# ───────────────────────────────────────────────────────────────────
echo_step "5" "Starting" "Creating default bitrix roles with permissions and views"
superset bx roles-create
echo_step "5" "Completed" "Creating default bitrix roles with permissions and views"
