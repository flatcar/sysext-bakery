#!/bin/bash
set -euo pipefail

ARCH="${ARCH-x86_64}"
OS="${OS-flatcar}"
FORMAT="${FORMAT:-squashfs}"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the wasmtime release tar ball (e.g., for 4.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  echo "To build for another OS than Flatcar, pass 'OS=myosid' as environment variable (current value is '${OS}'), e.g., 'fedora' as found in 'ID' under '/etc/os-release'."
  echo "The '/etc/os-release' file of your OS has to include 'SYSEXT_LEVEL=1.0' as done in Flatcar."
  echo "If the mksquashfs tool is missing you can pass FORMAT=btrfs, FORMAT=ext4, or FORMAT=ext2 as environment variable but the files won't be owned by root."
  echo
  exit 1
fi

if [ "${FORMAT}" != "squashfs" ] && [ "${FORMAT}" != "btrfs" ] && [ "${FORMAT}" != "ext4" ] && [ "${FORMAT}" != "ext2" ]; then
  echo "Expected FORMAT=squashfs, FORMAT=btrfs, FORMAT=ext4, or FORMAT=ext2, got '${FORMAT}'" >&2
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

rm -f "wasmtime-${VERSION}.tar.xz"
curl -o "wasmtime-${VERSION}.tar.xz" -fsSL "https://github.com/bytecodealliance/wasmtime/releases/download/v${VERSION}/wasmtime-v${VERSION}-${ARCH}-linux.tar.xz"
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"
tar -xf "wasmtime-${VERSION}.tar.xz" -C "${SYSEXTNAME}"
rm "wasmtime-${VERSION}.tar.xz"
mkdir -p "${SYSEXTNAME}"/usr/bin
mv "${SYSEXTNAME}"/"wasmtime-v${VERSION}-${ARCH}-linux"/wasmtime "${SYSEXTNAME}"/usr/bin/
rm -r "${SYSEXTNAME}"/"wasmtime-v${VERSION}-${ARCH}-linux"
mkdir -p "${SYSEXTNAME}/usr/lib/extension-release.d"
{ echo "ID=${OS}" ; echo "SYSEXT_LEVEL=1.0" ; } > "${SYSEXTNAME}/usr/lib/extension-release.d/extension-release.${SYSEXTNAME}"
rm -f "${SYSEXTNAME}".raw
if [ "${FORMAT}" = "btrfs" ]; then
  # Note: We didn't chown to root:root, meaning that the file ownership is left as is
  mkfs.btrfs --mixed -m single -d single --shrink --rootdir "${SYSEXTNAME}" "${SYSEXTNAME}".raw
  # This is for testing purposes and makes not much sense to use because --rootdir doesn't allow to enable compression
elif [ "${FORMAT}" = "ext4" ] || [ "${FORMAT}" = "ext2" ]; then
  # Assuming that 1 GB is enough
  truncate -s 1G "${SYSEXTNAME}".raw
  # Note: We didn't chown to root:root, meaning that the file ownership is left as is
  mkfs."${FORMAT}" -E root_owner=0:0 -d "${SYSEXTNAME}" "${SYSEXTNAME}".raw
  resize2fs -M "${SYSEXTNAME}".raw
else
  mksquashfs "${SYSEXTNAME}" "${SYSEXTNAME}".raw -all-root
fi
rm -rf "${SYSEXTNAME}"
echo "Created ${SYSEXTNAME}.raw"
