#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the WasmEdge release tar ball (e.g., for 0.14.1) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
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
  ARCH="x86_64"
elif [ "${ARCH}" = "arm64" ]; then
  ARCH="aarch64"
fi

rm -f "WasmEdge-${VERSION}.tar.gz"
curl -o "WasmEdge-${VERSION}.tar.gz" -fsSL "https://github.com/WasmEdge/WasmEdge/releases/download/${VERSION}/WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"
tar --force-local -xvf "WasmEdge-${VERSION}.tar.gz" -C "${SYSEXTNAME}"
rm "WasmEdge-${VERSION}.tar.gz"
mkdir -p "${SYSEXTNAME}"/usr/bin
mkdir -p "${SYSEXTNAME}"/usr/lib # for .so files
mv "${SYSEXTNAME}"/"WasmEdge-${VERSION}-Linux"/bin/wasmedge "${SYSEXTNAME}"/usr/bin/
mv "${SYSEXTNAME}"/"WasmEdge-${VERSION}-Linux"/lib/* "${SYSEXTNAME}"/usr/lib/
rm -r "${SYSEXTNAME}"/"WasmEdge-${VERSION}-Linux"
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
