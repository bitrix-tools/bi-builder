#!/usr/bin/env bash
# Generates .env file from .env.example with automatic substitution of passwords and keys.

set -euo pipefail

ENV_EXAMPLE=".env.example"
ENV_FILE=".env"

if [ ! -f "$ENV_EXAMPLE" ]; then
    echo "File $ENV_EXAMPLE not found." >&2
    exit 1
fi

if [ -f "$ENV_FILE" ]; then
    echo "File $ENV_FILE is already exists."
    read -rp "Overwrite? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo ".env generation cancelled."
        exit 0
    fi
fi

gen() {
    openssl rand -base64 "$1" | tr -dc 'A-Za-z0-9' | head -c "$1"
}

# Cross-platform sed in-place (BSD sed on macOS requires '' after -i)
sedi() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# --- Ask portal connection parameters ---

ask_required() {
    local prompt="$1"
    local value=""
    while [ -z "$value" ]; do
        read -rp "$prompt" value
        if [ -z "$value" ]; then
            echo "  This parameter is required, cannot be empty." >&2
        fi
    done
    echo "$value"
}

echo ""
echo "Portal connection parameters:"
echo ""

echo "Select portal scheme:"
echo "  1) https (default)"
echo "  2) http"
read -rp "Enter 1 or 2 [1]: " scheme_choice
case "$scheme_choice" in
    2)     BX_PORTAL_SCHEME="http" ;;
    1|"")  BX_PORTAL_SCHEME="https" ;;
    *)
        echo "  Invalid choice, using https." >&2
        BX_PORTAL_SCHEME="https"
        ;;
esac
echo "  Selected: ${BX_PORTAL_SCHEME}"

BX_PORTAL_HOST_INPUT=$(ask_required "Portal address (e.g. mycompany.bitrix24.ru): ")

BX_PORTAL_URL_VALUE="${BX_PORTAL_SCHEME}://${BX_PORTAL_HOST_INPUT}"

# --- Generate .env ---

cp "$ENV_EXAMPLE" "$ENV_FILE"

sedi "s|BX_PORTAL_URL=.*|BX_PORTAL_URL=${BX_PORTAL_URL_VALUE}|" "$ENV_FILE"
sedi "s|BX_PORTAL_HOST=.*|BX_PORTAL_HOST=${BX_PORTAL_HOST_INPUT}|" "$ENV_FILE"

sedi "s|BI_BUILDER_SECRET_KEY=CHANGE_ME_TO_A_COMPLEX_RANDOM_SECRET|BI_BUILDER_SECRET_KEY=$(gen 42)|" "$ENV_FILE"
sedi "s|DATABASE_PASSWORD=CHANGE_DATABASE_PASSWORD_SUPERSET|DATABASE_PASSWORD=$(gen 32)|" "$ENV_FILE"
sedi "s|MYSQL_ROOT_PASSWORD=CHANGE_ROOT_PASSWORD_SUPERSET|MYSQL_ROOT_PASSWORD=$(gen 32)|" "$ENV_FILE"
sedi "s|BI_BUILDER_ADMIN_PASSWORD=CHANGE_BI_BUILDER_ADMIN_PASSWORD|BI_BUILDER_ADMIN_PASSWORD=$(gen 32)|" "$ENV_FILE"
sedi "s|TRINO_CLIENT_KEY=CHANGE_TRINO_CLIENT_KEY|TRINO_CLIENT_KEY=$(gen 32)|" "$ENV_FILE"
sedi "s|TRINO_PASS=CHANGE_TRINO_ADMIN_PASS|TRINO_PASS=$(gen 32)|" "$ENV_FILE"
sedi "s|TRINO_INTERNAL_SECRET=CHANGE_TRINO_INTERNAL_SECRET|TRINO_INTERNAL_SECRET=$(gen 40)|" "$ENV_FILE"
sedi "s|SYMMETRIC_CRYPTO_KEY=.*|SYMMETRIC_CRYPTO_KEY=$(dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr '+/' '-_')|" "$ENV_FILE"
sedi "s|^BX_SELF_HOSTED_INSTANCE=.*|BX_SELF_HOSTED_INSTANCE=Y|" "$ENV_FILE"

echo ""
echo "File $ENV_FILE was successfully created."
echo ""
echo "Portal parameters:"
echo "  - BX_PORTAL_URL=${BX_PORTAL_URL_VALUE}"
echo "  - BX_PORTAL_HOST=${BX_PORTAL_HOST_INPUT}"
echo ""
echo "Generated parameters:"
echo "  - BI_BUILDER_SECRET_KEY"
echo "  - DATABASE_PASSWORD"
echo "  - MYSQL_ROOT_PASSWORD"
echo "  - BI_BUILDER_ADMIN_PASSWORD"
echo "  - TRINO_CLIENT_KEY"
echo "  - TRINO_PASS"
echo "  - TRINO_INTERNAL_SECRET"
echo "  - SYMMETRIC_CRYPTO_KEY"
echo ""
echo "For additional network settings (BX_PORTAL_IP, shared Docker network, etc.) see .env and README."
