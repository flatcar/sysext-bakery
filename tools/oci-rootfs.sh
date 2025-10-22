#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY-docker.io}"
ARCH="${ARCH-amd64}"
CMD="${CMD-}"
FETCH="${FETCH-1}"
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 IMAGE FOLDER"
  echo "The script will pull 'REGISTRY/ARCH/IMAGE' with Docker, and export the contents to FOLDER."
  echo "To run a command in the container before exporting pass 'CMD=...' as environemnt variable (current value is '${CMD}')."
  echo "To use a different registry than docker.io pass 'REGISTRY=...' as environment variable (current value is '${REGISTRY}')."
  echo "To use a different architecture than amd64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  echo "To skip fetching the image pass 'FETCH=0' as environment variable."
  echo
  exit 1
fi

IMAGE="$1"
FOLDER="$2"

SUFFIX=""
# Map to valid values for Docker
if [ "${ARCH}" = "x86-64" ] || [ "${ARCH}" = "x86_64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
  ARCH="arm64"
  SUFFIX="v8"
fi

IMAGE="${REGISTRY}/${ARCH}${SUFFIX}/${IMAGE}"

DOCKER="docker"
if command -v podman >/dev/null; then
  DOCKER="podman"
fi

rm -rf "${FOLDER}"
if [ "${FETCH}" = 1 ]; then
  "${DOCKER}" pull "${IMAGE}"
fi
if [ "${CMD}" != "" ]; then
  ID="$$"
else
  ID=$("${DOCKER}" create "${IMAGE}")
fi
echo "Using temporary container ${ID}"
trap "'${DOCKER}' rm --force --time 0 '${ID}'" EXIT INT
if [ "${CMD}" != "" ]; then
  "${DOCKER}" run --name "${ID}" "${IMAGE}" sh -c "${CMD}"
fi
rm -f "${FOLDER}.tar"
"${DOCKER}" export "${ID}" -o "${FOLDER}.tar"
mkdir -p "${FOLDER}"
tar --force-local -xf "${FOLDER}.tar" -C "${FOLDER}"
rm "${FOLDER}.tar"
