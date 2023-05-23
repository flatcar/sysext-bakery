#!/bin/bash
set -euo pipefail

export ARCH="${ARCH-x86_64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the docker compose CLI plugin binary (e.g., for 2.18.1) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/local/lib/docker/cli-plugins
curl -o "${SYSEXTNAME}"/usr/local/lib/docker/cli-plugins/docker-compose -fsSL "https://github.com/docker/compose/releases/download/v${VERSION}/docker-compose-linux-${ARCH}"
chmod +x "${SYSEXTNAME}"/usr/local/lib/docker/cli-plugins/docker-compose
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
