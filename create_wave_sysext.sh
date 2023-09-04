#!/bin/bash
set -euo pipefail
set -x
export ARCH="${ARCH-x86_64}"
export FILE_ARCH="x86-64"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the WaVe release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"


# clone and install tooling (x86_64 only atm)
# https://github.com/PLSysSec/wave

git clone https://github.com/PLSysSec/wave
cd wave

# If necessary
# sudo apt-get install -y curl git unzip build-essential pkg-config libssl-dev cmake ninja-build clang

# if necessary
# cargo install --force cbindgen


make bootstrap # Setup build the first time. This will take 15-20 minutes.
make build     # Build WaVe. This should take < 1 minute. 
cargo test     # Run all compliance tests. This should take < 1 minute
# make verify    # Verify correctness of WaVe. This will take 30-60 minutes.


# clean and obtain the specified version
rm -f "wasmtime-v${VERSION}-${ARCH}-linux.tar.xz"
curl -o "wasmtime-v${VERSION}-${ARCH}-linux.tar.xz" -L "https://github.com/bytecodealliance/wasmtime/releases/download/v${VERSION}/wasmtime-v${VERSION}-${ARCH}-linux.tar.xz"

# clean earlier SYSEXTNAME directory and recreate
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
