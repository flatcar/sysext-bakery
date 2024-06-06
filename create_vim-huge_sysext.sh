#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the vim version you choose (e.g. 9.0.1678 ), build a static binary and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "The build process requires docker"
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

if ! command -v docker &>/dev/null; then
  echo Missing docker in path
  exit 1
fi

SUFFIX=
if  [ "${ARCH}" = "x86-64" ] || [ "${ARCH}" = "x86_64" ]; then
  ARCH=amd64
elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
  ARCH="arm64"
  SUFFIX="v8"
fi
IMG=docker.io/"${ARCH}${SUFFIX}"/alpine:3.19
mkdir -p "${SYSEXTNAME}"
cat >"${SYSEXTNAME}"/build.sh <<EOF
#!/bin/sh
set -euo pipefail
cd /opt && wget https://github.com/vim/vim/archive/v${VERSION}.tar.gz && tar xfz v${VERSION}.tar.gz && cd vim-${VERSION}
apk --no-cache add gcc make musl-dev ncurses-static autoconf automake alpine-sdk
LDFLAGS="-static" ./configure --prefix=/usr --sysconfdir /etc/ --disable-channel --disable-gpm --disable-gtktest --disable-gui --disable-netbeans --disable-nls --disable-selinux --disable-smack --disable-sysmouse --disable-xsmp --enable-multibyte --with-features=huge --without-x --with-tlib=ncursesw --mandir=/tmp --docdir=/tmp 
make -j16
make DESTDIR=/install_root install
rm -rfv /install_root/usr/share/applications /install_root/usr/share/icons /install_root/usr/share/man
chown \$(stat -c %u:%g /install_root/build.sh) /install_root -R
EOF
chmod +x "${SYSEXTNAME}"/build.sh
docker run -v "${PWD}/${SYSEXTNAME}":/install_root/  --rm "${IMG}" /bin/sh -c /install_root/build.sh
rm -f "${SYSEXTNAME}"/build.sh
RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
