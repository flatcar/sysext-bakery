#!/bin/ash
#
# Build script helper for keepalived sysext.
# This script runs inside an ephemeral alpine container.
# It builds a static keepalived and exports the binary to a bind-mounted volume.
#
set -euo pipefail

version="$1"
export_user_group="$2"

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
cd /opt/keepalived

git checkout $version
./autogen.sh

CFLAGS='-static -s' LDFLAGS=-static \
     ./configure  --disable-dynamic-linking \
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

make
make DESTDIR=/install_root install

rm -rf /install_root/usr/share \
       /install_root/usr/etc/keepalived/samples
chown -R "$export_user_group" /install_root
