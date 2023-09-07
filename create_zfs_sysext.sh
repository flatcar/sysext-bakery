#!/bin/bash
set -euo pipefail

export ARCH="${ARCH-amd64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 3 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME FLATCARVERSION"
  echo "The script will build ZFS modules and tooling and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"
FLATCARVERSION="$3"
if [ "${ARCH}" = aarch64 ]; then
  ARCH=arm64
fi
rm -f ${SYSEXTNAME}

# base
echo "========== Prepare base"
emerge-gitclone
echo 'FEATURES="-network-sandbox -pid-sandbox -ipc-sandbox -usersandbox -sandbox"' >>/etc/portage/make.conf
cp files/zfs/repos.conf /etc/portage/repos.conf/zfs.conf
cp -r files/zfs/${FLATCARVERSION}/overlay/ /var/lib/portage/zfs-overlay/

# build zfs
echo "========== Build ZFS"
kernel=$(ls /lib/modules) && KBUILD_OUTPUT=/lib/modules/${kernel}/build KERNEL_DIR=/lib/modules/${kernel}/source emerge -j$(nproc) --getbinpkg --onlydeps zfs
emerge -j$(nproc) --getbinpkg --buildpkgonly zfs squashfs-tools

# install deps 
echo "========== Install deps"
emerge --getbinpkg --usepkg squashfs-tools

# flatcar layout compat
echo "========== Create Flatcar layout"
mkdir -p ${SYSEXTNAME} ; for dir in lib lib64 bin sbin; do mkdir -p ${SYSEXTNAME}/usr/$dir; ln -s usr/$dir ${SYSEXTNAME}/$dir; done
echo "========== Copy kernel modules to workdir"
mkdir -p ${SYSEXTNAME}/lib/modules
rsync -a /lib/modules/${kernel} ${SYSEXTNAME}/lib/modules/
echo "========== Emerge packages"
pkgs=$(emerge 2>/dev/null --usepkgonly --pretend zfs| awk -F'] ' '/binary/{ print $ 2 }' | awk '{ print "="$1 }'); emerge --usepkgonly --root=${SYSEXTNAME} --nodeps $pkgs
mv ${SYSEXTNAME}/etc ${SYSEXTNAME}/usr/etc
echo "========== Copy static files (systemd) to workdir"
rsync -a files/zfs/usr/ ${SYSEXTNAME}/usr/

# clean uneeded files 
echo "========== Cleaning"
rm -rf ${SYSEXTNAME}/var/db
rm -rf ${SYSEXTNAME}/var/cache
rm -rf ${SYSEXTNAME}/usr/share
rm -rf ${SYSEXTNAME}/usr/src
rm -rf ${SYSEXTNAME}/usr/include



"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}" "${FLATCARVERSION}"
rm -rf "${SYSEXTNAME}"
