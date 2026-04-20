#!/bin/bash

# Usage: ./update-env.sh <resource-group-name>
# This script fetches Azure resource values and populates a .env file.

RESOURCE_GROUP="$1"
# Get the script directory and set ENV_FILE to root of repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../.env"

if [ -z "$RESOURCE_GROUP" ]; then
  echo "Usage: $0 <resource-group-name>"
  exit 1
fi

echo "Fetching Azure resource values for resource group: $RESOURCE_GROUP"

# Get Subscription ID
SUBSCRIPTION_ID=$(az group show --name "$RESOURCE_GROUP" --query "id" -o tsv | cut -d'/' -f3)

# Get AI Foundry Hub resource name (the CognitiveServices account that hosts projects)
AI_FOUNDRY_NAME=$(az cognitiveservices account list --resource-group "$RESOURCE_GROUP" --query "[?kind=='AIServices' || kind=='OpenAI'].name | [0]" -o tsv)

# Get AI Project name (the project nested under the AI Foundry hub)
AI_PROJECT_FULL=$(az resource list --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.CognitiveServices/accounts/projects" --query "[0].name" -o tsv)
# Extract just the project name (after the /)
AI_PROJECT_NAME="${AI_PROJECT_FULL##*/}"

# Get OpenAI endpoint, API version, and API key
# First, try to find a dedicated OpenAI resource
OPENAI_RESOURCE=$(az cognitiveservices account list --resource-group "$RESOURCE_GROUP" --query "[?kind=='OpenAI'].name | [0]" -o tsv)

# If not found, look for AIServices account (which includes OpenAI)
if [ -z "$OPENAI_RESOURCE" ]; then
  echo "No dedicated OpenAI resource found. Looking for AIServices account..."
  OPENAI_RESOURCE=$(az cognitiveservices account list --resource-group "$RESOURCE_GROUP" --query "[?kind=='AIServices'].name | [0]" -o tsv)
fi

if [ -n "$OPENAI_RESOURCE" ]; then
  # Try to get the OpenAI-specific endpoint from the endpoints object
  OPENAI_ENDPOINT=$(az cognitiveservices account show --name "$OPENAI_RESOURCE" --resource-group "$RESOURCE_GROUP" --query "properties.endpoints.\"OpenAI Language Model Instance API\"" -o tsv 2>/dev/null)
  
  # If that doesn't work, try alternate endpoint names
  if [ -z "$OPENAI_ENDPOINT" ] || [ "$OPENAI_ENDPOINT" == "null" ]; then
    echo "Trying alternate endpoint query..."
    OPENAI_ENDPOINT=$(az cognitiveservices account show --name "$OPENAI_RESOURCE" --resource-group "$RESOURCE_GROUP" --query "properties.endpoints.\"Azure OpenAI Legacy API - Latest moniker\"" -o tsv 2>/dev/null)
  fi
  
  # If still not found, construct it from the resource name
  if [ -z "$OPENAI_ENDPOINT" ] || [ "$OPENAI_ENDPOINT" == "null" ]; then
    echo "Constructing OpenAI endpoint from resource name..."
    OPENAI_ENDPOINT="https://${OPENAI_RESOURCE}.openai.azure.com/"
  fi
  
  # Ensure endpoint has proper format (https:// and trailing /)
  if [ -n "$OPENAI_ENDPOINT" ] && [ "$OPENAI_ENDPOINT" != "null" ]; then
    # Add https:// if not present
    if [[ ! "$OPENAI_ENDPOINT" =~ ^https?:// ]]; then
      OPENAI_ENDPOINT="https://${OPENAI_ENDPOINT}"
    fi
    # Add trailing slash if not present
    if [[ ! "$OPENAI_ENDPOINT" =~ /$ ]]; then
      OPENAI_ENDPOINT="${OPENAI_ENDPOINT}/"
    fi
  fi
  
  # Try to get API key
  OPENAI_API_KEY=$(az cognitiveservices account keys list --name "$OPENAI_RESOURCE" --resource-group "$RESOURCE_GROUP" --query "key1" -o tsv 2>/dev/null)
  if [ -z "$OPENAI_API_KEY" ]; then
    echo "Warning: Could not retrieve OpenAI API key automatically. You may need to retrieve it manually from the Azure Portal."
    OPENAI_API_KEY="<retrieve-from-portal>"
  fi
  
  echo "Found Azure resource: $OPENAI_RESOURCE"
  echo "OpenAI endpoint: $OPENAI_ENDPOINT"
else
  echo "ERROR: No Azure OpenAI or AIServices resource found in resource group $RESOURCE_GROUP"
  echo "Please ensure you have an Azure OpenAI service deployed."
  OPENAI_ENDPOINT="<not-found>"
  OPENAI_API_KEY="<not-found>"
fi

OPENAI_API_VERSION="2025-02-01-preview"

# Get AI Search endpoint, index name, and API key
SEARCH_RESOURCE=$(az resource list --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.Search/searchServices" --query "[0].name" -o tsv)
SEARCH_ENDPOINT="https://${SEARCH_RESOURCE}.search.windows.net/"
SEARCH_INDEX="zava-products"

# Get AI Search API key
SEARCH_API_KEY=$(az search admin-key show --resource-group "$RESOURCE_GROUP" --service-name "$SEARCH_RESOURCE" --query "primaryKey" -o tsv 2>/dev/null)
if [ -z "$SEARCH_API_KEY" ]; then
  echo "Warning: Could not retrieve Search API key automatically. You may need to retrieve it manually from the Azure Portal."
  SEARCH_API_KEY="<retrieve-from-portal>"
fi

# Model deployment info (from README)
OPENAI_DEPLOYMENT="gpt-4.1"
OPENAI_MODEL_VERSION="2025-04-14"


# Function to update or add env variable
update_env_var() {
  local key="$1"
  local value="$2"
  
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    # Update existing variable (works on both macOS and Linux)
    sed -i.bak "s|^${key}=.*|${key}=\"${value}\"|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
  else
    # Add new variable
    echo "${key}=\"${value}\"" >> "$ENV_FILE"
  fi
}

# Update all environment variables
update_env_var "AZURE_SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
update_env_var "AZURE_RESOURCE_GROUP" "$RESOURCE_GROUP"
update_env_var "AZURE_OPENAI_API_KEY" "$OPENAI_API_KEY"
update_env_var "AZURE_OPENAI_ENDPOINT" "$OPENAI_ENDPOINT"
update_env_var "AZURE_OPENAI_API_VERSION" "$OPENAI_API_VERSION"
update_env_var "AZURE_AI_FOUNDRY_NAME" "$AI_FOUNDRY_NAME"
update_env_var "AZURE_AI_PROJECT_NAME" "$AI_PROJECT_NAME"
update_env_var "AZURE_OPENAI_DEPLOYMENT" "$OPENAI_DEPLOYMENT"
update_env_var "AZURE_OPENAI_MODEL_VERSION" "$OPENAI_MODEL_VERSION"
update_env_var "AZURE_SEARCH_ENDPOINT" "$SEARCH_ENDPOINT"
update_env_var "AZURE_SEARCH_INDEX_NAME" "$SEARCH_INDEX"
update_env_var "AZURE_SEARCH_API_KEY" "$SEARCH_API_KEY"

echo ".env file updated at: $ENV_FILE"
echo "Successfully populated values from resource group: $RESOURCE_GROUP"
