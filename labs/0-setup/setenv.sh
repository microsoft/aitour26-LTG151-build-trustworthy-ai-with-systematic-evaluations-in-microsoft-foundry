#!/usr/bin/env bash
# ============================================================
#  Contoso Travel Workshop — Environment Setup Script
# ============================================================
#  This script:
#    1. Checks Azure CLI login status (prompts az login if needed)
#    2. Creates a .env file from sample.env (if it doesn't exist)
#    3. Auto-populates values it can discover via Azure CLI
#    4. Reports which values still need manual entry
#
#  Usage:
#    chmod +x setup-env.sh
#    ./setup-env.sh
#
#  Prerequisites:
#    - Azure CLI (az) installed
#    - A Microsoft Foundry project already created
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
SAMPLE_FILE="${SCRIPT_DIR}/sample.env"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  🧳 Contoso Travel Workshop — Environment Setup        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ────────────────────────────────────────────────────────────
#  Step 1: Check Azure CLI login
# ────────────────────────────────────────────────────────────
echo -e "${BLUE}[1/5]${NC} Checking Azure CLI authentication..."

if ! command -v az &> /dev/null; then
    echo -e "${RED}  ✗ Azure CLI (az) is not installed.${NC}"
    echo "    Install it: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

if az account show &> /dev/null; then
    ACCOUNT_NAME=$(az account show --query "user.name" -o tsv 2>/dev/null || echo "unknown")
    SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv 2>/dev/null || echo "unknown")
    echo -e "${GREEN}  ✓ Logged in as: ${ACCOUNT_NAME}${NC}"
    echo -e "${GREEN}  ✓ Subscription: ${SUBSCRIPTION_NAME}${NC}"
else
    echo -e "${YELLOW}  ⚠ Not logged in to Azure CLI.${NC}"
    echo -e "${YELLOW}    Running 'az login --use-device-code'...${NC}"
    echo ""
    az login --use-device-code || true
    echo ""
    if ! az account show &> /dev/null; then
        echo -e "${RED}  ✗ Azure login failed. Please try again.${NC}"
        exit 1
    fi
    ACCOUNT_NAME=$(az account show --query "user.name" -o tsv 2>/dev/null || echo "unknown")
    SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv 2>/dev/null || echo "unknown")
    echo -e "${GREEN}  ✓ Login successful!${NC}"
    echo -e "${GREEN}  ✓ Logged in as: ${ACCOUNT_NAME}${NC}"
    echo -e "${GREEN}  ✓ Subscription: ${SUBSCRIPTION_NAME}${NC}"
fi

# ────────────────────────────────────────────────────────────
#  Step 2: Create .env from sample.env if it doesn't exist
# ────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[2/5]${NC} Checking .env file..."

if [ ! -f "${SAMPLE_FILE}" ]; then
    echo -e "${RED}  ✗ sample.env not found at: ${SAMPLE_FILE}${NC}"
    echo "    Make sure you're running this script from the labs/notebooks/ directory."
    exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
    cp "${SAMPLE_FILE}" "${ENV_FILE}"
    echo -e "${GREEN}  ✓ Created .env from sample.env${NC}"
else
    echo -e "${GREEN}  ✓ .env already exists (will update empty values)${NC}"
    # Ensure any new keys from sample.env are present in existing .env
    while IFS='=' read -r key value; do
        [[ "${key}" =~ ^#.*$ ]] && continue
        [[ -z "${key}" ]] && continue
        if ! grep -q "^${key}=" "${ENV_FILE}" 2>/dev/null; then
            echo "${key}=${value}" >> "${ENV_FILE}"
            echo -e "${GREEN}  + Added new key: ${key}${NC}"
        fi
    done < <(grep "^[A-Z]" "${SAMPLE_FILE}")
fi

# ────────────────────────────────────────────────────────────
#  Helper: set a value in .env only if currently empty
# ────────────────────────────────────────────────────────────
set_env_if_empty() {
    local key="$1"
    local value="$2"
    # Ensure the key exists in .env (append if missing)
    if ! grep -q "^${key}=" "${ENV_FILE}" 2>/dev/null; then
        echo "${key}=" >> "${ENV_FILE}"
    fi
    local current
    current=$(grep "^${key}=" "${ENV_FILE}" | cut -d'=' -f2-)
    if [ -z "${current}" ] && [ -n "${value}" ]; then
        # Quote values to handle special characters (semicolons, parens, etc.)
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "${ENV_FILE}"
        echo -e "${GREEN}  ✓ ${key} → ${value:0:50}...${NC}"
        return 0
    elif [ -n "${current}" ]; then
        echo -e "${GREEN}  ✓ ${key} already set${NC}"
        return 0
    else
        return 1
    fi
}

# ────────────────────────────────────────────────────────────
#  Step 3: Get resource group from user & subscription info
# ────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[3/5]${NC} Azure resource configuration..."

# Get subscription ID
SUB_ID=$(az account show --query "id" -o tsv 2>/dev/null || echo "")
set_env_if_empty "AZURE_SUBSCRIPTION_ID" "${SUB_ID}" || true

# Ask user to enter the resource group name
echo ""
read -rp "  Enter your Azure resource group name: " SELECTED_RG

if [ -z "${SELECTED_RG}" ]; then
    echo -e "${RED}  ✗ Resource group name cannot be empty.${NC}"
    exit 1
fi

# Validate the resource group exists
if ! az group show --name "${SELECTED_RG}" &>/dev/null; then
    echo -e "${RED}  ✗ Resource group '${SELECTED_RG}' not found in subscription '${SUBSCRIPTION_NAME}'.${NC}"
    echo -e "${RED}    Check the name and make sure you're logged in to the correct subscription.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓ Using resource group: ${SELECTED_RG}${NC}"
set_env_if_empty "AZURE_RESOURCE_GROUP" "${SELECTED_RG}" || true

# Discover AI Services / Foundry resources in the selected resource group
echo ""
echo -e "${BLUE}[4/5]${NC} Discovering resources in ${SELECTED_RG}..."

# ── Find AI Services account ──
ACCOUNT_NAME=$(az cognitiveservices account list \
    --resource-group "${SELECTED_RG}" \
    --query "[?kind=='AIServices' || kind=='OpenAI'] | [0].name" \
    -o tsv 2>/dev/null || echo "")

if [ -z "${ACCOUNT_NAME}" ]; then
    echo -e "${YELLOW}  ⚠ No AI Services accounts found in resource group '${SELECTED_RG}'.${NC}"
    echo -e "${YELLOW}    Create a Foundry project first (see Lab 00).${NC}"
else
    echo -e "${GREEN}  ✓ AI Services account: ${ACCOUNT_NAME}${NC}"

    # ── Get API key ──
    API_KEY=$(az cognitiveservices account keys list \
        --name "${ACCOUNT_NAME}" \
        --resource-group "${SELECTED_RG}" \
        --query "key1" -o tsv 2>/dev/null || echo "")
    if [ -n "${API_KEY}" ]; then
        set_env_if_empty "MODEL_API_KEY" "${API_KEY}" || true
    else
        echo -e "${YELLOW}  ⚠ Could not retrieve API key (check permissions)${NC}"
    fi

    # ── Find Foundry project via resource query ──
    PROJECT_NAME=""
    PROJECT_ENDPOINT=""
    PROJECT_RESOURCE=$(az resource list \
        --resource-group "${SELECTED_RG}" \
        --resource-type "Microsoft.CognitiveServices/accounts/projects" \
        --query "[0].name" \
        -o tsv 2>/dev/null || echo "")

    if [ -n "${PROJECT_RESOURCE}" ]; then
        # Resource name format is "account/project", extract just the project part
        PROJECT_NAME=$(echo "${PROJECT_RESOURCE}" | cut -d'/' -f2)
        PROJECT_ENDPOINT="https://${ACCOUNT_NAME}.services.ai.azure.com/api/projects/${PROJECT_NAME}"
        echo -e "${GREEN}  ✓ Foundry project: ${PROJECT_NAME}${NC}"
        set_env_if_empty "AZURE_AI_PROJECT_ENDPOINT" "${PROJECT_ENDPOINT}" || true
    else
        echo -e "${YELLOW}  ⚠ No Foundry project found in resource group '${SELECTED_RG}'${NC}"
        echo -e "${YELLOW}    Set AZURE_AI_PROJECT_ENDPOINT manually in .env${NC}"
    fi

    # ── Build MODEL_ENDPOINT via API Management gateway ──
    APIM_NAME=$(az resource list \
        --resource-group "${SELECTED_RG}" \
        --resource-type "Microsoft.ApiManagement/service" \
        --query "[0].name" \
        -o tsv 2>/dev/null || echo "")

    if [ -n "${APIM_NAME}" ] && [ -n "${PROJECT_NAME:-}" ]; then
        # Get the gateway URL from the APIM resource
        GATEWAY_URL=$(az resource show \
            --resource-type "Microsoft.ApiManagement/service" \
            --name "${APIM_NAME}" \
            --resource-group "${SELECTED_RG}" \
            --query "properties.gatewayUrl" \
            -o tsv 2>/dev/null || echo "")

        if [ -n "${GATEWAY_URL}" ]; then
            GATEWAY_URL="${GATEWAY_URL%/}"   # strip trailing slash
            MODEL_ENDPOINT="${GATEWAY_URL}/${ACCOUNT_NAME}/api/projects/${PROJECT_NAME}/openai/v1/responses"
            echo -e "${GREEN}  ✓ API Management gateway: ${APIM_NAME}${NC}"
            set_env_if_empty "MODEL_ENDPOINT" "${MODEL_ENDPOINT}" || true
        else
            MODEL_ENDPOINT="https://${ACCOUNT_NAME}.services.ai.azure.com"
            set_env_if_empty "MODEL_ENDPOINT" "${MODEL_ENDPOINT}" || true
        fi
    else
        MODEL_ENDPOINT="https://${ACCOUNT_NAME}.services.ai.azure.com"
        set_env_if_empty "MODEL_ENDPOINT" "${MODEL_ENDPOINT}" || true
    fi

    # ── Find model deployments via ARM REST (most reliable) ──
    ACCOUNT_ID=$(az cognitiveservices account show \
        --name "${ACCOUNT_NAME}" \
        --resource-group "${SELECTED_RG}" \
        --query "id" \
        -o tsv 2>/dev/null || echo "")

    DEPLOY_NAME=""
    if [ -n "${ACCOUNT_ID}" ]; then
        # Prefer GPT deployments when available.
        DEPLOY_NAME=$(az rest \
            --method get \
            --url "https://management.azure.com${ACCOUNT_ID}/deployments?api-version=2024-10-01" \
            --query "value[?contains(name, 'gpt')].name | [0]" \
            -o tsv 2>/dev/null || echo "")

        if [ -z "${DEPLOY_NAME}" ]; then
            DEPLOY_NAME=$(az rest \
                --method get \
                --url "https://management.azure.com${ACCOUNT_ID}/deployments?api-version=2024-10-01" \
                --query "value[0].name" \
                -o tsv 2>/dev/null || echo "")
        fi
    fi

    if [ -n "${DEPLOY_NAME}" ]; then
        echo -e "${GREEN}  ✓ Model deployment: ${DEPLOY_NAME}${NC}"
        set_env_if_empty "AZURE_AI_MODEL_DEPLOYMENT_NAME" "${DEPLOY_NAME}" || true
    else
        EXISTING_DEPLOYMENT=$(grep '^AZURE_AI_MODEL_DEPLOYMENT_NAME=' "${ENV_FILE}" | cut -d'=' -f2- | tr -d '"' || true)
        if [ -n "${EXISTING_DEPLOYMENT}" ]; then
            echo -e "${GREEN}  ✓ AZURE_AI_MODEL_DEPLOYMENT_NAME already set: ${EXISTING_DEPLOYMENT}${NC}"
        else
            echo -e "${YELLOW}  ⚠ No model deployments found. Deploy a model (e.g., gpt-4.1-mini) in the Foundry portal.${NC}"
            echo -e "${YELLOW}    Then run this script again or set AZURE_AI_MODEL_DEPLOYMENT_NAME manually.${NC}"
        fi
    fi

    # ── Find Application Insights ──
    APP_INSIGHTS=""
    APP_INSIGHTS_RG="${SELECTED_RG}"

    # First: look in the user's resource group
    APP_INSIGHTS=$(az resource list \
        --resource-group "${SELECTED_RG}" \
        --resource-type "Microsoft.Insights/components" \
        --query "[0].name" \
        -o tsv 2>/dev/null || echo "")

    # Fallback: search subscription-wide for App Insights linked to this project
    if [ -z "${APP_INSIGHTS}" ]; then
        APP_INSIGHTS_RESOURCE=$(az resource list \
            --resource-type "Microsoft.Insights/components" \
            --query "[0].{name:name, rg:resourceGroup}" -o json 2>/dev/null || echo "")
        if [ -n "${APP_INSIGHTS_RESOURCE}" ] && [ "${APP_INSIGHTS_RESOURCE}" != "[]" ]; then
            APP_INSIGHTS=$(echo "${APP_INSIGHTS_RESOURCE}" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('name',''))" 2>/dev/null || echo "")
            APP_INSIGHTS_RG=$(echo "${APP_INSIGHTS_RESOURCE}" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('rg',''))" 2>/dev/null || echo "")
        fi
    fi

    if [ -n "${APP_INSIGHTS}" ]; then
        APP_INSIGHTS_ID=$(az resource list \
            --resource-group "${APP_INSIGHTS_RG}" \
            --resource-type "Microsoft.Insights/components" \
            --query "[?name=='${APP_INSIGHTS}'].id | [0]" \
            -o tsv 2>/dev/null || echo "")

        TELEMETRY_CONN=""
        if [ -n "${APP_INSIGHTS_ID}" ]; then
            TELEMETRY_CONN=$(az rest \
                --method get \
                --url "https://management.azure.com${APP_INSIGHTS_ID}?api-version=2020-02-02" \
                --query "properties.ConnectionString" \
                -o tsv 2>/dev/null || echo "")
        fi

        if [ -n "${TELEMETRY_CONN}" ]; then
            echo -e "${GREEN}  ✓ Application Insights: ${APP_INSIGHTS}${NC}"
            set_env_if_empty "TELEMETRY_CONNECTION_STRING" "${TELEMETRY_CONN}" || true
        else
            echo -e "${YELLOW}  ⚠ Could not retrieve App Insights connection string${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ No Application Insights found in subscription${NC}"
        echo -e "${YELLOW}    Set TELEMETRY_CONNECTION_STRING manually if needed for tracing labs${NC}"
    fi
fi

# Set defaults for SDK configuration variables
set_env_if_empty "AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED" "true" || true
set_env_if_empty "AZURE_LOG_LEVEL" "error" || true

# ────────────────────────────────────────────────────────────
#  Step 5: Final report
# ────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}[5/5]${NC} Verifying .env configuration..."
echo ""

MISSING=0
# Optional vars that don't block workshop progress
OPTIONAL_VARS="AZURE_SUBSCRIPTION_ID AZURE_RESOURCE_GROUP TELEMETRY_CONNECTION_STRING AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED AZURE_LOG_LEVEL"
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "${key}" =~ ^#.*$ ]] && continue
    [[ -z "${key}" ]] && continue
    IS_OPTIONAL=false
    for opt in ${OPTIONAL_VARS}; do
        [[ "${key}" == "${opt}" ]] && IS_OPTIONAL=true && break
    done
    if [ -z "${value}" ]; then
        if [ "${IS_OPTIONAL}" = true ]; then
            echo -e "  ${YELLOW}○ ${key} — not set (optional)${NC}"
        else
            echo -e "  ${RED}✗ ${key} — NOT SET${NC}"
            MISSING=$((MISSING + 1))
        fi
    else
        DISPLAY="${value:0:40}"
        [ ${#value} -gt 40 ] && DISPLAY="${DISPLAY}..."
        echo -e "  ${GREEN}✓ ${key} = ${DISPLAY}${NC}"
    fi
done < <(grep "^[A-Z]" "${ENV_FILE}")

echo ""
if [ "${MISSING}" -eq "0" ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  🎉 All required variables are set! You're ready.       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠  ${MISSING} variable(s) need manual entry.                  ║${NC}"
    echo -e "${YELLOW}║  Edit: ${ENV_FILE}  ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "  ${CYAN}📄 .env location: ${ENV_FILE}${NC}"
echo -e "  ${CYAN}📝 Reference:     ${SAMPLE_FILE}${NC}"
echo ""