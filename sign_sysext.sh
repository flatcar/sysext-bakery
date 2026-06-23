#!/bin/bash

set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"

function fail() {
  echo "$@"
  exit 1
}

function generate_repart_config() {
  FS_IMAGE="$1"

  # Create temporary working directory
  WORKDIR=$(mktemp -d)
  FS_IMAGE="$FS_IMAGE" envsubst < repart.d/wrap-fs-in-ddi/10-root.conf > "$WORKDIR/10-root.conf"
  cp repart.d/wrap-fs-in-ddi/20-verity.conf "$WORKDIR"
  cp repart.d/wrap-fs-in-ddi/30-signature.conf "$WORKDIR"

  echo "$WORKDIR"
}

function usage() {
    echo "Usage: $0 <sysext_name> <private_key_spec> [<cert_path>]"
    exit 1
}

function sign_sysext() {
  FS_IMAGE="$1"
  OUTPUT_IMAGE="$2"
  KEY_SPEC="$3"
  CERT_SPEC="$4"

  REPART_CONFIG_PATH=$(generate_repart_config "$FS_IMAGE")
  trap 'rm -rf "$REPART_CONFIG_PATH"' EXIT

  PKCS11_ENV=()
  AZURE_VARS=(
    AZURE_CLIENT_ID
    AZURE_TENANT_ID
    AZURE_SUBSCRIPTION_ID
    AZURE_KEYVAULT_URL
    PKCS11_MODULE_PATH
    AZURE_KEYVAULT_PKCS11_DEBUG
  )
  for VARNAME in "${AZURE_VARS[@]}"; do
    if [ -n "${!VARNAME+x}" ]; then
      set +u
      VAL="${!VARNAME}"
      set -u

      PKCS11_ENV+=("${VARNAME}=${VAL}")
    fi
  done

  PRIVATE_KEY_SOURCE="file"
  if [[ ${KEY_SPEC} == pkcs11:* ]]; then
    PRIVATE_KEY_SOURCE="engine:pkcs11"
  fi

  if [[ ${CERT_SPEC} == pkcs11:* ]]; then
    CERT_CONTENT=$(env "${PKCS11_ENV[@]}" p11-kit export-object "$CERT_SPEC")
  else
    CERT_CONTENT=$(cat "$CERT_SPEC")
  fi
  env "${PKCS11_ENV[@]}" systemd-repart \
    --empty=create \
    --size=auto \
    --private-key-source=$PRIVATE_KEY_SOURCE \
    --private-key="$KEY_SPEC" \
    --certificate=<(echo "$CERT_CONTENT") \
    --definitions="$REPART_CONFIG_PATH" \
   "$OUTPUT_IMAGE"
}

if [[ "$#" -lt 2 || "$#" -gt 3 ]]; then
    usage
fi

# strip the version after colon
SYSEXT_NAME="${1%:*}"

KEY_SPEC="$2"
if [[ "$#" -eq 2 && ${KEY_SPEC} != pkcs11:* ]]; then
  fail "You have to specify cert_path when not using PKCS11 token."
fi
CERT_NAME="${3:-${KEY_SPEC};type=cert}"

for raw_image in "${SYSEXT_NAME}"*.raw; do
  echo "Signing $raw_image with key $KEY_SPEC and cert $CERT_NAME"
  signed_image_path="${raw_image%.raw}-signed-ddi.raw"
  raw_image=$(readlink -f "$raw_image")
  sign_sysext "$raw_image" "$signed_image_path" "$KEY_SPEC" "$CERT_NAME"
done

for conf_file in "$SYSEXT_NAME"*.conf; do
  echo "Modifying sysupdate config $conf_file"
  sed -E 's/^(MatchPattern.*)\.raw/\1-signed-ddi.raw/g' > "${conf_file%.conf}-signed-ddi.conf" < "$conf_file"
done
