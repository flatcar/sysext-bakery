#!/bin/bash
set -euo pipefail

export ARCH="${ARCH-x86_64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the wasmtime release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

echo "https://github.com/deislabs/containerd-wasm-shims/releases/download/${VERSION}/containerd-wasm-shims-v1-linux-${ARCH}.tar.gz --output containerd-wasm-shims-v1-linux-${ARCH}.tar.gz"

# clean and obtain the specified version
rm -f "containerd-wasm-shims-v1-linux-${VERSION}-${ARCH}.tar.gz"
curl -o "containerd-wasm-shims-v1-linux-${VERSION}-${ARCH}.tar.gz" -fsSL "https://github.com/deislabs/containerd-wasm-shims/releases/download/${VERSION}/containerd-wasm-shims-v1-linux-${ARCH}.tar.gz" --output "containerd-wasm-shims-v1-linux-${ARCH}.tar.gz"

# clean earlier SYSEXTNAME directory and recreate
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# extract wasmtime into SYSEXTNAME/
tar --force-local -xf "containerd-wasm-shims-v1-linux-${VERSION}-${ARCH}.tar.gz" -C "${SYSEXTNAME}"

# clean downloaded tarball
rm "containerd-wasm-shims-v1-linux-${VERSION}-${ARCH}.tar.gz"

# create deployment directory in SYSEXTNAME/ and move wasmtime into it
mkdir -p "${SYSEXTNAME}"/usr/bin
mv "${SYSEXTNAME}"/containerd-shim* "${SYSEXTNAME}"/usr/bin/

# clean up any extracted mess
rm -r "${SYSEXTNAME}"/*

# bake the .raw
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}-${VERSION}-${ARCH}"

# clean again just in case
rm -rf "${SYSEXTNAME}"
