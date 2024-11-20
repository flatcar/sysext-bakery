#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download tailscale binaries (e.g., for 1.64.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

if [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "aarch64" ]; then
  ARCH="arm64"
fi

TARBALL="tailscale_${VERSION}_${ARCH}.tgz"
URL="https://pkgs.tailscale.com/stable/${TARBALL}"

rm -rf "${SYSEXTNAME}"
TMP_DIR="${SYSEXTNAME}/tmp"
mkdir -p "${TMP_DIR}"

curl -o "${TMP_DIR}/${TARBALL}" -fsSL "${URL}"

tar xf "${TMP_DIR}/${TARBALL}" -C "${TMP_DIR}" --strip-components=1

mkdir -p "${SYSEXTNAME}"/usr/local/{bin,sbin,lib/{systemd/system,extension-release.d}}

mv "${TMP_DIR}/tailscale" "${SYSEXTNAME}/usr/local/bin/tailscale"
mv "${TMP_DIR}/tailscaled" "${SYSEXTNAME}/usr/local/sbin/tailscaled"
mv "${TMP_DIR}/systemd/tailscaled.service" "${SYSEXTNAME}/usr/local/lib/systemd/system/tailscaled.service"

sed -i 's/--port.*//g' "${SYSEXTNAME}/usr/local/lib/systemd/system/tailscaled.service"

rm -rf "${TMP_DIR}"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
