#!/bin/ash
#
# Build script helper for chrony sysext.
# This script runs inside an ephemeral alpine container.
# It builds a static chrony and exports the binary to a bind-mounted volume.
# See https://gitlab.com/chrony/chrony/-/blob/master/doc/installation.adoc for install instructions.
# 
set -euo pipefail

version="$1"
export_user_group="$2"

apk --no-cache add \
  git \
  asciidoctor \
  make \
  build-base \
  bison

cd /opt
git clone https://gitlab.com/chrony/chrony.git --depth 1 --branch ${version} --single-branch
cd /opt/chrony

CFLAGS='-static -s' LDFLAGS=-static \
  ./configure \
    --prefix=/usr \
    --exec_prefix=/usr \
    --sbindir=/usr/bin \
    --sysconfdir=/etc/chrony \
    --mandir=/usr/share/man \
    --localstatedir=/var \
    --runstatedir=/run \
    --with-iproutedir=/usr/share/iproute2
make
make DESTDIR=/install_root install

rm -rf /install_root/usr/etc
chown -R "$export_user_group" /install_root
