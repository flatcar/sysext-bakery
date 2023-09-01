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
SPIN_VERSION="$3"
SYSEXTNAME="$4"

echo "${SYSEXTNAME}"

# Constructing download SPIN_FILE and SPIN_URL
SPIN_FILE="spin-${SPIN_VERSION}-linux-amd64.tar.gz" # current version  spin-v1.4.1-linux-amd64.tar.gz
SPIN_URL="https://github.com/fermyon/spin/releases/download/${SPIN_VERSION}/${SPIN_FILE}"  

# clean old version
rm -f "wasmtime-${WASMTIME_VERSION}.tar.xz"
# get new version
curl -o "wasmtime-${WASMTIME_VERSION}.tar.xz" -fsSL "https://github.com/bytecodealliance/wasmtime/releases/download/v${WASMTIME_VERSION}/wasmtime-v${WASMTIME_VERSION}-${ARCH}-linux.tar.xz"

# clean and download x86 first
rm -f "slight.tgz"
curl -L -s https://github.com/deislabs/spiderlightning/releases/download/${SLIGHT_VERSION}/slight-linux-x86_64.tar.gz -o slight.tgz

# clean and download new version
rm -f "${SPIN_FILE}"
curl -L -s "${SPIN_URL}" -o "${SPIN_FILE}"



#clean old sysextname directory and remake it
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# tar into systextname directory the wasmtime binary, the slight binary, and the spin binary
tar --force-local -xf "wasmtime-${WASMTIME_VERSION}.tar.xz" -C "${SYSEXTNAME}"
tar --force-local -xf "slight.tgz" -C "${SYSEXTNAME}"
tar --force-local -xvf "${SPIN_FILE}" -C "${SYSEXTNAME}"

#clean up remaining local wasmtime
rm "wasmtime-${WASMTIME_VERSION}.tar.xz"
rm "slight.tgz"
rm "${SPIN_FILE}"

# make a /usr/bin in sysextname directory
mkdir -p "${SYSEXTNAME}"/usr/bin

# move wasmtime into sysextname/usr/bin/
mv "${SYSEXTNAME}"/"wasmtime-v${WASMTIME_VERSION}-${ARCH}-linux"/wasmtime "${SYSEXTNAME}"/usr/bin/
mv "${SYSEXTNAME}"/release/slight "${SYSEXTNAME}/usr/bin"
mv "${SYSEXTNAME}"/spin "${SYSEXTNAME}/usr/bin"

# clean up temp directory for wasmtime
rm -r "${SYSEXTNAME}"/"wasmtime-v${WASMTIME_VERSION}-${ARCH}-linux"
rm -r "${SYSEXTNAME}"/"release"
rm -r "${SYSEXTNAME}"/"LICENSE" "${SYSEXTNAME}"/"README.md" # leaving these for now: "${SYSEXTNAME}"/"crt.pem" "${SYSEXTNAME}"/"spin.sig"

# bake the image
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

#clean up the sysextname directory
rm -rf "${SYSEXTNAME}"
