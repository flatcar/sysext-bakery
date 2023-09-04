#!/bin/bash
set -euo pipefail
set -x
export ARCH="${ARCH-x86_64}"
export FILE_ARCH="x86-64"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the modsurfer release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# https://github.com/dylibso/modsurfer/releases/download/v/modsurfer-${ARCH}-unknown-linux-gnu.tar.gz

# clean and obtain the specified version
rm -f "modsurfer-${ARCH}-unknown-linux-gnu.tar.gz"
curl -o "modsurfer-${ARCH}-unknown-linux-gnu.tar.gz" -L "https://github.com/dylibso/modsurfer/releases/download/v${VERSION}/modsurfer-${ARCH}-unknown-linux-gnu.tar.gz"

# clean earlier SYSEXTNAME directory and recreate
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# extract modsurfer into SYSEXTNAME/
tar --force-local -xvf "modsurfer-${ARCH}-unknown-linux-gnu.tar.gz" -C "${SYSEXTNAME}"

# clean downloaded tarball
rm "modsurfer-${ARCH}-unknown-linux-gnu.tar.gz"

# create deployment directory in SYSEXTNAME/ and move modsurfer into it
mkdir -p "${SYSEXTNAME}"/usr/bin
mv "${SYSEXTNAME}"/modsurfer "${SYSEXTNAME}"/usr/bin/

# clean up any extracted mess
rm -r "${SYSEXTNAME}"/LICENSE "${SYSEXTNAME}"/README.md

# bake the .raw. This process uses the generic binary name for layer metadata
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${VERSION}-${FILE_ARCH}.raw"

# clean again just in case
rm -rf "${SYSEXTNAME}" 
