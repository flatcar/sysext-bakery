#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the rke2 binary (e.g., for v1.29.2+rke2r1) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
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
        export ARCH="amd64"
elif [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "aarch64" ]; then
        export ARCH="arm64"
fi
URL="https://github.com/rancher/rke2/releases/download/${VERSION}/rke2.linux-${ARCH}.tar.gz"
SHA256SUMS="https://github.com/rancher/rke2/releases/download/${VERSION}/sha256sum-${ARCH}.txt"

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}/usr/local/"

TMP_DIR="${SYSEXTNAME}/tmp/"
mkdir -p "${TMP_DIR}"
curl -o "${TMP_DIR}/rke2.linux-${ARCH}.tar.gz"  -fsSL "${URL}"
curl -o "${TMP_DIR}/sha256sums"  -fsSL "${SHA256SUMS}"
pushd "${TMP_DIR}" > /dev/null
grep "rke2.linux-${ARCH}.tar.gz" ./sha256sums | sha256sum -c -
popd  > /dev/null

tar xf "${TMP_DIR}/rke2.linux-${ARCH}.tar.gz" -C "${SYSEXTNAME}/usr/local/"
rm "${SYSEXTNAME}/usr/local/bin/rke2-uninstall.sh"

# remove TMP_DIR before building the sysext
rm -rf "${TMP_DIR}"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# cleanup
rm -rf "${SYSEXTNAME}"
