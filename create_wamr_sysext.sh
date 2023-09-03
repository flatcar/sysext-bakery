#!/bin/bash
set -euo pipefail
set -x
export ARCH="${ARCH-x86_64}"
export FILE_ARCH="x86-64"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the wamr release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"


# curl -L https://github.com/bytecodealliance/wasm-micro-runtime/releases/download/WAMR-${VERSION}/iwasm-${VERSION}-x86_64-ubuntu-22.04.tar.gz --output wamr.tar.gz
# tar -xvf wamr.tar.gz 

# clean and obtain the specified version
rm -f "iwasm-${VERSION}-${ARCH}-ubuntu-22.04.tar.gz"
curl -o "iwasm-${VERSION}-${ARCH}-ubuntu-22.04.tar.gz" -fsSL "https://github.com/bytecodealliance/wasm-micro-runtime/releases/download/WAMR-${VERSION}/iwasm-${VERSION}-${ARCH}-ubuntu-22.04.tar.gz"

# clean earlier SYSEXTNAME directory and recreate
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# extract wasmtime into SYSEXTNAME/
tar --force-local -xvf "iwasm-${VERSION}-${ARCH}-ubuntu-22.04.tar.gz" -C "${SYSEXTNAME}"

# clean downloaded tarball
rm "iwasm-${VERSION}-${ARCH}-ubuntu-22.04.tar.gz"

# create deployment directory in SYSEXTNAME/ and move wasmtime into it
mkdir -p "${SYSEXTNAME}"/usr/bin
mv "${SYSEXTNAME}"/iwasm "${SYSEXTNAME}"/usr/bin/

# clean up any extracted mess
rm -r "${SYSEXTNAME}"

# bake the .raw
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${VERSION}-${FILE_ARCH}.raw"

# clean again just in case
rm -rf "${SYSEXTNAME}"
