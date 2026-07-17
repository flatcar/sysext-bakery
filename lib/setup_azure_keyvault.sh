#!/usr/bin/env bash
set -euo pipefail

libroot="$(dirname "$(readlink -f "$0")")"

if [[ $# -eq 0 || $# -ge 3 ]]; then
  echo "Usage: $0 <RG name> [<AZURE_SUBSCRIPTION_ID>]"
  echo "Note: AZURE_SUBSCRIPTION_ID can also be specified via environment variable"
  exit 1
fi

set +u
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$2}"
set -u
RG_NAME="$1"
LOCATION="westeurope"
KV_NAME="sysext-bakery"
CERT_NAME="sysext-bakery-signing"
IDENTITY_NAME="sysext-bakery-github-actions"
FED_CRED_NAME="gh-main"
GITHUB_REPO=$(source "${libroot}/libbakery.sh"; echo "$bakery") # owner/repo
GITHUB_BRANCH="main"

echo "Setting subscription..."
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
TENANT_ID="$(az account show --query tenantId -o tsv)"

echo "Creating resource group $RG_NAME in $LOCATION..."
az group create -n "$RG_NAME" -l "$LOCATION" -o none

# ============
# KEY VAULT
# ============
echo "Creating Key Vault $KV_NAME..."
# Enable RBAC authorization and purge protection (soft-delete is on by default)
#
az keyvault show -n "$KV_NAME" -g "$RG_NAME" -o none 2>/dev/null || \
  az keyvault create \
    --name "$KV_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku standard \
    --enable-purge-protection true \
    --enable-rbac-authorization true \
    -o none
KV_ID="$(az keyvault show -n "$KV_NAME" -g "$RG_NAME" --query id -o tsv)"

# 2) Get your Azure AD object id (the caller shown in the error)
#    This works when you're logged in as a user (not a service principal)
USER_OID=$(az ad signed-in-user show --query id -o tsv)
USER_NAME=$(az ad signed-in-user show --query userPrincipalName -o tsv)
RG_ID=$(az group show -n "$RG_NAME" --query id -o tsv)

# 3) Grant yourself a data-plane role that includes certificate create
#    Pick ONE of the two; Administrator is broader than Certificates Officer.
for role in "Key Vault Administrator" "Owner"; do
  echo "Granting $role role in RG $RG_NAME to $USER_NAME"
  az role assignment create \
    --assignee-object-id "$USER_OID" \
    --assignee-principal-type User \
    --role "$role" \
    --scope "$RG_ID" \
    -o none
done

echo "Waiting 30 seconds for the permissions to apply. If the script fails, please wait and run it again."
sleep 30

# ============
# CERTIFICATE
# ============
echo "Creating self-signed certificate $CERT_NAME in $KV_NAME (default policy)..."
DEFAULT_POLICY="$(az keyvault certificate get-default-policy)"
az keyvault certificate show --vault-name "$KV_NAME" -n "$CERT_NAME" -o none 2>/dev/null || \
  az keyvault certificate create \
    --vault-name "$KV_NAME" \
    --name "$CERT_NAME" \
    --policy "$DEFAULT_POLICY" \
    -o none

# ===============================
# USER-ASSIGNED MANAGED IDENTITY
# ===============================
echo "Creating user-assigned managed identity $IDENTITY_NAME..."
az identity show --name "$IDENTITY_NAME" --resource-group "$RG_NAME" -o none 2>/dev/null || \
  az identity create \
    --name "$IDENTITY_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    -o none

IDENTITY_JSON="$(az identity show -n "$IDENTITY_NAME" -g "$RG_NAME")"
IDENTITY_CLIENT_ID="$(echo "$IDENTITY_JSON" | jq -r .clientId)"
IDENTITY_PRINCIPAL_ID="$(echo "$IDENTITY_JSON" | jq -r .principalId)"
# IDENTITY_ID="$(echo "$IDENTITY_JSON" | jq -r .id)"

echo "Identity clientId:    $IDENTITY_CLIENT_ID"
echo "Identity principalId: $IDENTITY_PRINCIPAL_ID"

# =====================================
# FEDERATED CREDENTIAL FOR GITHUB OIDC
# =====================================
echo "Creating federated credential $FED_CRED_NAME on identity $IDENTITY_NAME for repo $GITHUB_REPO branch ${GITHUB_BRANCH}..."
ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"
SUBJECT="repo:${GITHUB_REPO}:ref:refs/heads/${GITHUB_BRANCH}"

az identity federated-credential show --name "$FED_CRED_NAME" --identity-name "$IDENTITY_NAME" --resource-group "$RG_NAME" -o none > /dev/null 2>&1 || \
  az identity federated-credential create \
    --name "$FED_CRED_NAME" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RG_NAME" \
    --issuer "$ISSUER" \
    --subject "$SUBJECT" \
    --audiences "$AUDIENCE" \
    -o none

# ==================================
# ROLE ASSIGNMENTS (Key Vault RBAC)
# ==================================

IDENTITY_NAME="sysext-bakery-github-actions"
PRINCIPAL_ID=$(az identity show -n "$IDENTITY_NAME" -g "$RG_NAME" --query principalId -o tsv)
for role in "Key Vault Crypto User" "Key Vault Secrets User" "Key Vault Reader"; do
  echo "Granting $role role in RG $RG_NAME to $IDENTITY_NAME"
  az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope "$RG_ID" \
    -o none
done

# az role assignment create \
#   --assignee-object-id "$PRINCIPAL_ID" \
#   --assignee-principal-type ServicePrincipal \
#   --role "Reader" \
#   --scope "$KV_ID"

echo "All done."
echo "---------------------------------------------"
echo "Key Vault:           $KV_NAME"
echo "Certificate:         $CERT_NAME"
echo "Managed Identity:    $IDENTITY_NAME"
echo "Identity clientId:   $IDENTITY_CLIENT_ID"
echo "Tenant ID:           $TENANT_ID"
echo "Subscription ID:     $AZURE_SUBSCRIPTION_ID"
echo "---------------------------------------------"
echo ""
echo "Please set these GitHub secrets on repo ${GITHUB_REPO}:"
echo ""
echo "---------------------------------------------"
echo "AZURE_CLIENT_ID       : $IDENTITY_CLIENT_ID"
echo "AZURE_SUBSCRIPTION_ID : $AZURE_SUBSCRIPTION_ID"
echo "AZURE_TENANT_ID       : $TENANT_ID"
echo "KEYVAULT_CERT_NAME    : $CERT_NAME"
echo "KEYVAULT_NAME         : $KV_NAME"
echo ""
echo "You can do it like this:"
echo ""
echo "echo '$IDENTITY_CLIENT_ID' | gh secret set --repo '$GITHUB_REPO' AZURE_CLIENT_ID"
echo "echo '$AZURE_SUBSCRIPTION_ID' | gh secret set --repo '$GITHUB_REPO' AZURE_SUBSCRIPTION_ID"
echo "echo '$TENANT_ID' | gh secret set --repo '$GITHUB_REPO' AZURE_TENANT_ID"
echo "echo '$CERT_NAME' | gh secret set --repo '$GITHUB_REPO' KEYVAULT_CERT_NAME"
echo "echo '$KV_NAME' | gh secret set --repo '$GITHUB_REPO' KEYVAULT_NAME"
echo "---------------------------------------------"
