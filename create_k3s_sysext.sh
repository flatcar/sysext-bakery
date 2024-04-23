#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the k3s binary (e.g., for v1.29.2+k3s1) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# The github release uses different arch identifiers, we map them here
# and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "x86-64" ]; then
  URL="https://github.com/k3s-io/k3s/releases/download/${VERSION}/k3s"
elif [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "aarch64" ]; then
  URL="https://github.com/k3s-io/k3s/releases/download/${VERSION}%2Bk3s1/k3s-arm64"
fi

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/local/bin
curl -o "${SYSEXTNAME}/usr/local/bin/k3s" -fsSL "${URL}"
chmod +x "${SYSEXTNAME}"/usr/local/bin/k3s
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
