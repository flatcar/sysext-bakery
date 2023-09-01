#!/bin/bash
set -euo pipefail
set -x
export ARCH="${ARCH-x86_64}"
export FILE_ARCH="x86-64"
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

# clean and download x86 first
rm -f "lunatic.gz"
curl -L -s https://github.com/lunatic-solutions/lunatic/releases/download/v${VERSION}/lunatic-linux-amd64.tar.gz -o lunatic.gz

#clean old sysextname directory and remake it
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# tar into systextname directory the lunatic binary
tar --force-local -xf "lunatic.gz" -C "${SYSEXTNAME}"

#clean up remaining local lunatic
rm "lunatic.gz"

# make a /usr/bin in sysextname directory
mkdir -p "${SYSEXTNAME}"/usr/bin

# move lunatic into sysextname/usr/bin/
mv "${SYSEXTNAME}"/lunatic "${SYSEXTNAME}/usr/bin"

# clean up any extracted mess
rm -rf "${SYSEXTNAME}"/LICEN* "${SYSEXTNAME}"/README.md

# bake the image
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${VERSION}-${FILE_ARCH}.raw"

#clean up the sysextname directory
rm -rf "${SYSEXTNAME}"
