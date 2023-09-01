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

SLIGHT_VERSION="$1"
SYSEXTNAME="$2"

# clean and download x86 first
rm -f "slight.tgz"
curl -L -s https://github.com/deislabs/spiderlightning/releases/download/${SLIGHT_VERSION}/slight-linux-x86_64.tar.gz -o slight.tgz

#clean old sysextname directory and remake it
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# tar into systextname directory the slight binary
tar --force-local -xf "slight.tgz" -C "${SYSEXTNAME}"

#clean up remaining local slight
rm "slight.tgz"

# make a /usr/bin in sysextname directory
mkdir -p "${SYSEXTNAME}"/usr/bin

# move slight into sysextname/usr/bin/
mv "${SYSEXTNAME}"/release/slight "${SYSEXTNAME}/usr/bin"

# clean up temp directory for slight
rm -r "${SYSEXTNAME}"/"release"

# bake the image
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

#clean up the sysextname directory
rm -rf "${SYSEXTNAME}"
