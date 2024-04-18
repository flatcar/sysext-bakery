#!/usr/bin/env bash
set -euo pipefail

OS="${OS-_any}"
FORMAT="${FORMAT:-squashfs}"
ARCH="${ARCH-}"
RELOAD="${RELOAD-}"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH-0}"
export SOURCE_DATE_EPOCH

# This script is to be called as helper by other scripts but can also be used standalone
if [ $# -lt 1 ]; then
  echo "Usage: $0 SYSEXTNAME"
  echo "The script will make a SYSEXTNAME.raw image of the folder SYSEXTNAME, and create an os-release file in it, run with --help for the list of supported environment variables."
  exit 1
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "If ARCH is specified as environment variable the sysext image will be required to run on the given architecture."
  echo "To build for a specific OS, pass 'OS=myosid' as environment variable (current value is '${OS}'), e.g., 'fedora' as found in 'ID' under '/etc/os-release', or pass 'OS=_any' for any OS."
  echo "The '/etc/os-release' file of your OS has to include 'SYSEXT_LEVEL=1.0' as done in Flatcar (not needed for 'OS=_any')."
  echo "To specify that systemd should do a daemon reload for the system when the extension is loaded/unloaded, set RELOAD=1 (current value is '${RELOAD}')."
  echo "If the mksquashfs tool is missing you can pass FORMAT=btrfs, FORMAT=ext4, or FORMAT=ext2 as environment variable (current value is '${FORMAT}') but the script won't change the ownership of the files in the SYSEXTNAME directory, so make sure that they are owned by root before creating the sysext image to avoid any problems."
  echo "To make builds reproducible the SOURCE_DATE_EPOCH environment variable will be set to 0 if not defined."
  echo
  exit 1
fi

SYSEXTNAME="$1"

if [ "${FORMAT}" != "squashfs" ] && [ "${FORMAT}" != "btrfs" ] && [ "${FORMAT}" != "ext4" ] && [ "${FORMAT}" != "ext2" ]; then
  echo "Expected FORMAT=squashfs, FORMAT=btrfs, FORMAT=ext4, or FORMAT=ext2, got '${FORMAT}'" >&2
  exit 1
fi

# Map to valid values for https://www.freedesktop.org/software/systemd/man/os-release.html#ARCHITECTURE=
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "x86_64" ]; then
  ARCH="x86-64"
elif [ "${ARCH}" = "aarch64" ]; then
  ARCH="arm64"
fi

mkdir -p "${SYSEXTNAME}/usr/lib/extension-release.d"
{
  echo "ID=${OS}"
  if [ "${OS}" != "_any" ]; then
    echo "SYSEXT_LEVEL=1.0"
  fi
  if [ "${ARCH}" != "" ]; then
    echo "ARCHITECTURE=${ARCH}"
  fi
  if [ "${RELOAD}" = 1 ]; then
    echo "EXTENSION_RELOAD_MANAGER=1"
  fi
} > "${SYSEXTNAME}/usr/lib/extension-release.d/extension-release.${SYSEXTNAME}"
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
  VER=$({ mksquashfs -version || true ; } | head -n1 | cut -d " " -f 3)
  VERMAJ=$(echo "${VER}" | cut -d . -f 1)
  VERMIN=$(echo "${VER}" | cut -d . -f 2)
  ARG=(-all-root -noappend)
  if [ "${VERMAJ}" -gt 4 ] && [ "${VERMIN}" -gt 6 ]; then
    ARG+=('-xattrs-exclude' '^btrfs.')
  fi
  mksquashfs "${SYSEXTNAME}" "${SYSEXTNAME}".raw "${ARG[@]}"
fi
echo "Created ${SYSEXTNAME}.raw"
