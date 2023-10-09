#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the wasmtime release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
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

rm -f "wasmtime-${VERSION}.tar.xz"
curl -o "wasmtime-${VERSION}.tar.xz" -fsSL "https://github.com/bytecodealliance/wasmtime/releases/download/v${VERSION}/wasmtime-v${VERSION}-${ARCH}-linux.tar.xz"
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# extract wasmtime into SYSEXTNAME/
tar --force-local -xvf "wasmtime-v${VERSION}-${ARCH}-linux.tar.xz" -C "${SYSEXTNAME}"

# clean downloaded tarball
rm "wasmtime-v${VERSION}-${ARCH}-linux.tar.xz"

# create deployment directory in SYSEXTNAME/ and move wasmtime into it
mkdir -p "${SYSEXTNAME}"/usr/bin
mv "${SYSEXTNAME}"/"wasmtime-v${VERSION}-${ARCH}-linux"/wasmtime "${SYSEXTNAME}"/usr/bin/

# clean up any extracted mess
rm -r "${SYSEXTNAME}"/"wasmtime-v${VERSION}-${ARCH}-linux"

# bake the .raw. This process uses the generic binary name for layer metadata
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${VERSION}-${FILE_ARCH}.raw"

# clean again just in case
rm -rf "${SYSEXTNAME}" 
