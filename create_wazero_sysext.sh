#!/bin/bash
set -euo pipefail
set -x
export ARCH="${ARCH-x86_64}"
export FILE_ARCH="x86-64"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the wazero release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# clean and obtain the specified version
rm -f "wazero_${VERSION}_linux_amd64.tar.gz"
curl -o "wazero_${VERSION}_linux_amd64.tar.gz" -L "https://github.com/tetratelabs/wazero/releases/download/v${VERSION}/wazero_${VERSION}_linux_amd64.tar.gz"

# clean earlier SYSEXTNAME directory and recreate
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# extract wazero into SYSEXTNAME/
tar --force-local -xvf "wazero_${VERSION}_linux_amd64.tar.gz" -C "${SYSEXTNAME}"

# clean downloaded tarball
rm "wazero_${VERSION}_linux_amd64.tar.gz"

# create deployment directory in SYSEXTNAME/ and move wazero into it
mkdir -p "${SYSEXTNAME}"/usr/bin
mv "${SYSEXTNAME}"/wazero "${SYSEXTNAME}"/usr/bin/

# clean up any extracted mess
#rm -r "${SYSEXTNAME}"/"wazero-v${VERSION}-${ARCH}-linux"

# bake the .raw. This process uses the generic binary name for layer metadata
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${VERSION}-${FILE_ARCH}.raw"

# clean again just in case
rm -rf "${SYSEXTNAME}" 
