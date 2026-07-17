#!/bin/bash

SYSEXT_NAME="$1"
KEYVAULT_CERT_NAME="$2"

if [ -n "${AZURE_FEDERATED_TOKEN_FILE+x}" ]; then
  echo "Obtaining OIDC token..."
  token=$(curl -sSL \
    -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=api://AzureADTokenExchange" \
    | jq -r '.value')
  echo "$token" > "$AZURE_FEDERATED_TOKEN_FILE"
fi

./sign_sysext.sh "$SYSEXT_NAME" pkcs11:token="$KEYVAULT_CERT_NAME"
