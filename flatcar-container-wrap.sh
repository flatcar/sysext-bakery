#!/bin/bash

FLATCAR_SDK_CONTAINER="ghcr.io/flatcar/flatcar-sdk-all"
LATEST_FLATCAR_SDK_VERSION=$(skopeo list-tags docker://${FLATCAR_SDK_CONTAINER} | \
   jq -r '.Tags[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)
EXCLUDED_VARS="^(DIRSTACK|HOME|HOSTNAME|LOGNAME|MAIL|OLDPWD|PATH|PWD|USER|USERNAME|XDG_DATA_DIRS|BASH.*|EPOCH|RANDOM)$"

ARGS=("--rm" "--volume" "/tmp:/tmp" "--volume" "$PWD:/app" --entrypoint "" --workdir "/app" "--privileged" "--user" "sdk")
# Extra "sh -c" is needed to only export the exported variables
for VARNAME in $(bash -c "compgen -v | grep -vE \"$EXCLUDED_VARS\""); do
  set +u
  VAL="${!VARNAME}"
  set -u
  ARGS+=("--env" "${VARNAME}=${VAL}")
done

docker run "${ARGS[@]}" "${FLATCAR_SDK_CONTAINER}:$LATEST_FLATCAR_SDK_VERSION" \
  bash -c "$*"
