#!/bin/bash
set -euo pipefail
set -x
export ARCH="${ARCH-x86_64}"
export FILE_ARCH="x86-64"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the wasmedge release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# clean and obtain the specified version
rm -f "WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"
curl -o "WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz" -L "https://github.com/WasmEdge/WasmEdge/releases/download/${VERSION}/WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"

# clean earlier SYSEXTNAME directory and recreate
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# extract wasmtime into SYSEXTNAME/
tar --force-local -xvf "WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz" -C "${SYSEXTNAME}"

# ends up in WasmEdge-0.13.3-Linux/bin/wasmedge -- there's bin/ include/ lib/ to clean up

# clean downloaded tarball
rm "WasmEdge-${VERSION}-ubuntu20.04_${ARCH}.tar.gz"

# create deployment directory in SYSEXTNAME/ and move wasmtime into it
mkdir -p "${SYSEXTNAME}"/usr/bin # binary
mkdir -p "${SYSEXTNAME}"/usr/lib/wasmedge # .so files

mv "${SYSEXTNAME}"/WasmEdge-0.13.3-Linux/bin/wasmedge "${SYSEXTNAME}"/usr/bin/
mv "${SYSEXTNAME}"/WasmEdge-0.13.3-Linux/lib/* "${SYSEXTNAME}"/usr/lib/wasmedge/

# clean up any extracted mess # currently in WasmEdge-0.13.3-Linux/bin/wasmedge -- there's bin/ include/ lib/ to clean up
rm -rf "${SYSEXTNAME}"/WasmEdge-0.13.3-Linux/bin/ "${SYSEXTNAME}"/WasmEdge-0.13.3-Linux/include/ "${SYSEXTNAME}"/WasmEdge-0.13.3-Linux/lib

# bake the .raw. This process uses the generic binary name for layer metadata
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${VERSION}-${FILE_ARCH}.raw"

# clean again just in case
#rm -rf "${SYSEXTNAME}" 
