#!/usr/bin/env bash
set -euo pipefail

SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the keepalived from git, checkout the tag (e.g., for v2.2.8), build a static binary and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "The build process requires docker"
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

if ! which docker &>/dev/null; then
  echo Missing docker in path
  exit 1
fi

SUFFIX=
if  [ "${ARCH}" = "x86-64" ] || [ "${ARCH}" = "x86_64" ]; then
  ARCH=amd64
elif [ "${ARCH}" = "arm64" ]; then
  ARCH="aarch64"
  SUFFIX="v8"
fi
IMG=docker.io/"${ARCH}${SUFFIX}"/alpine:3.19
mkdir -p "${SYSEXTNAME}"
cat >"${SYSEXTNAME}"/build.sh <<EOF
#!/bin/sh
set -euo pipefail
apk --no-cache add \
        binutils \
        file \
        file-dev \
        gcc \
        glib \
        glib-dev \
        ipset \
        ipset-dev \
        iptables \
        iptables-dev \
        libmagic-static \
        libmnl-dev \
        libnftnl-dev \
        libnl3-static \
        libnl3-dev \
        make \
        musl-dev \
        net-snmp-dev \
        openssl \
        openssl-dev \
        openssl-libs-static \
        pcre2 \
        pcre2-dev \
        autoconf \
        automake zlib-static  alpine-sdk linux-headers libmnl-static git
cd /opt
git clone https://github.com/acassen/keepalived.git
    cd /opt/keepalived && git checkout $VERSION && \
    ./autogen.sh && \
    CFLAGS='-static -s' LDFLAGS=-static ./configure  --disable-dynamic-linking \
    --prefix=/usr \
    --exec-prefix=/usr \
    --bindir=/usr/bin \
    --sbindir=/usr/sbin \
    --sysconfdir=/usr/etc \
    --datadir=/usr/share \
    --localstatedir=/var \
    --mandir=/usr/share/man \
    --enable-bfd \
    --enable-nftables \
    --enable-regex \
    --enable-json  --with-init=systemd --enable-vrrp --enable-libnl-dynamic
set -ex && \
    cd /opt/keepalived && \
    make && \
    make DESTDIR=/install_root install && \
    find /install_root && \
    rm -rf /install_root/usr/share /install_root/usr/etc/keepalived/samples && chown \$(stat --format=%u:%g /install_root/build.sh) /install_root -R
EOF
chmod +x "${SYSEXTNAME}"/build.sh
docker run -v "${PWD}/${SYSEXTNAME}":/install_root/  --rm -it "${IMG}" /bin/sh -c /install_root/build.sh
mkdir -p  "${SYSEXTNAME}"/usr/lib/systemd/system/
cat > "${SYSEXTNAME}"/usr/lib/systemd/system/keepalived.service <<-'EOF'
[Unit]
Description=LVS and VRRP High Availability Monitor
After=network-online.target syslog.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/keepalived.pid
KillMode=process
EnvironmentFile=-/usr/etc/sysconfig/keepalived
EnvironmentFile=-/etc/sysconfig/keepalived
ExecStart=/usr/sbin/keepalived $KEEPALIVED_OPTIONS
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/keepalived.service.d
cat > "${SYSEXTNAME}"/usr/lib/systemd/system/keepalived.service.d/10-keepalived.conf <<-'EOF'
[Service]
ExecStartPre=/bin/bash -c 'set -e; mkdir -p /etc/keepalived/; if ! [ -e /etc/keepalived/keepalived.conf ]; then touch /etc/keepalived/keepalived.conf; fi' 
ExecStart=
ExecStart=/usr/sbin/keepalived --use-file /etc/keepalived/keepalived.conf $KEEPALIVED_OPTIONS
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d
{ echo "[Unit]"; echo "Upholds=keepalived.service"; } > "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d/10-keepalived.conf"
rm -f "${SYSEXTNAME}"/build.sh
RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"

