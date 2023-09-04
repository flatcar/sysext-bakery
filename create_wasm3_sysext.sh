#!/bin/bash
set -euo pipefail
set -x
export ARCH="${ARCH-x86_64}"
export FILE_ARCH="x86-64"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the wasm3 release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# clean and obtain the specified version
echo "Currently only the x86_64 architecture, though it supports a lot of them"
rm -f "wasm3-linux-x64.elf"
curl -o "wasm3-linux-x64.elf" -L "https://github.com/wasm3/wasm3/releases/download/v0.5.0/wasm3-linux-x64.elf"

# clean earlier SYSEXTNAME directory and recreate
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# extract wasm3 into SYSEXTNAME/
# no extraction necessary

# clean downloaded tarball
# not necessary

# create deployment directory in SYSEXTNAME/ and move wasmtime into it
mkdir -p "${SYSEXTNAME}"/usr/bin
mv ./wasm3-linux-x64.elf  "${SYSEXTNAME}"/usr/bin/wasm3

# clean up any extracted mess
# unnecessary

# bake the .raw. This process uses the generic binary name for layer metadata
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${VERSION}-${FILE_ARCH}.raw"

# clean again just in case
rm -rf "${SYSEXTNAME}" 
