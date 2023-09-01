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

SPIN_VERSION="$1"
SYSEXTNAME="$2"

echo "${SYSEXTNAME}"

# Constructing download SPIN_FILE and SPIN_URL
SPIN_FILE="spin-v${SPIN_VERSION}-linux-amd64.tar.gz" # current version  spin-v1.4.1-linux-amd64.tar.gz
SPIN_URL="https://github.com/fermyon/spin/releases/download/v${SPIN_VERSION}/${SPIN_FILE}"  


# clean and download new version
rm -f "${SPIN_FILE}"
curl -L -s "${SPIN_URL}" -o "${SPIN_FILE}"

#clean old sysextname directory and remake it
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

# tar into systextname directory the spin binary
tar --force-local -xvf "${SPIN_FILE}" -C "${SYSEXTNAME}"

#clean up remaining local spin
rm "${SPIN_FILE}"

# make a /usr/bin in sysextname directory
mkdir -p "${SYSEXTNAME}"/usr/bin

# move spin into sysextname/usr/bin/
mv "${SYSEXTNAME}"/spin "${SYSEXTNAME}/usr/bin"

# clean up temp directory for spin
# rm -r "${SYSEXTNAME}"/"LICENSE" "${SYSEXTNAME}"/"README.md" # leaving these for now: "${SYSEXTNAME}"/"crt.pem" "${SYSEXTNAME}"/"spin.sig"

# bake the image
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"

# rename the file to the specific version and arch.
mv "./${SYSEXTNAME}.raw" "./${SYSEXTNAME}-v${SPIN_VERSION}-${FILE_ARCH}.raw"

#clean up the sysextname directory
rm -rf "${SYSEXTNAME}"

