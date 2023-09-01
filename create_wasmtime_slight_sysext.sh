#!/bin/bash
set -euo pipefail

export ARCH="${ARCH-x86_64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 WASMTIME_VERSION SLIGHT_VERSION SYSEXTNAME"
  echo "The script will download the wasmtime release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

WASMTIME_VERSION="$1"
SLIGHT_VERSION="$2"
SYSEXTNAME="$3"



# clean old version
rm -f "wasmtime-${WASMTIME_VERSION}.tar.xz"
# get new version
curl -o "wasmtime-${WASMTIME_VERSION}.tar.xz" -fsSL "https://github.com/bytecodealliance/wasmtime/releases/download/v${WASMTIME_VERSION}/wasmtime-v${WASMTIME_VERSION}-${ARCH}-linux.tar.xz"

# clean and download x86 first
rm -f "slight.tgz"
curl -L -s https://github.com/deislabs/spiderlightning/releases/download/${SLIGHT_VERSION}/slight-linux-x86_64.tar.gz -o slight.tgz

#clean old sysextname directory and remake it
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# tar into systextname directory the wasmtime binary
tar --force-local -xf "wasmtime-${WASMTIME_VERSION}.tar.xz" -C "${SYSEXTNAME}"
tar --force-local -xf "slight.tgz" -C "${SYSEXTNAME}"

#clean up remaining local wasmtime
rm "wasmtime-${WASMTIME_VERSION}.tar.xz"
rm "slight.tgz"

# make a /usr/bin in sysextname directory
mkdir -p "${SYSEXTNAME}"/usr/bin

# move wasmtime into sysextname/usr/bin/
mv "${SYSEXTNAME}"/"wasmtime-v${WASMTIME_VERSION}-${ARCH}-linux"/wasmtime "${SYSEXTNAME}"/usr/bin/
mv "${SYSEXTNAME}"/release/slight "${SYSEXTNAME}/usr/bin"

# clean up temp directory for wasmtime
rm -r "${SYSEXTNAME}"/"wasmtime-v${WASMTIME_VERSION}-${ARCH}-linux"
rm -r "${SYSEXTNAME}"/"release"

# bake the image
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

#clean up the sysextname directory
rm -rf "${SYSEXTNAME}"
