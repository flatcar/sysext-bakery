#!/bin/ash
#
# Build script helper for the haproxy sysext.
# This script runs inside an ephemeral alpine container. It builds a
# statically linked haproxy from the upstream source release at
# https://www.haproxy.org/download/ and exports the binary to the
# bind-mounted /install_root.
#
set -euo pipefail

version="$1"
export_user_group="$2"

# Stable haproxy versions look like "3.2.5"; map to the upstream branch
# directory (e.g. "3.2") under https://www.haproxy.org/download/.
branch="$(echo "${version}" | awk -F. '{print $1"."$2}')"

apk --no-cache add \
  build-base \
  curl \
  linux-headers \
  openssl-dev \
  openssl-libs-static \
  pcre2-dev \
  zlib-dev \
  zlib-static

cd /opt
curl -fsSLO "https://www.haproxy.org/download/${branch}/src/haproxy-${version}.tar.gz"
curl -fsSLO "https://www.haproxy.org/download/${branch}/src/haproxy-${version}.tar.gz.sha256"
sha256sum -c "haproxy-${version}.tar.gz.sha256"

tar -xf "haproxy-${version}.tar.gz"
cd "haproxy-${version}"

# Build statically against musl. We deliberately omit Lua and the
# bundled QuicTLS so the resulting binary works on any Flatcar host
# without runtime dependencies.
make -j"$(nproc)" \
  TARGET=linux-musl \
  USE_OPENSSL=1 \
  USE_PCRE2=1 USE_PCRE2_JIT=1 USE_STATIC_PCRE2=1 \
  USE_ZLIB=1 \
  USE_THREAD=1 \
  USE_TFO=1 \
  USE_NS=1 \
  USE_GETADDRINFO=1 \
  USE_PROMEX=1 \
  USE_LINUX_TPROXY=1 \
  USE_LINUX_SPLICE=1 \
  USE_LINUX_CAP=1 \
  LDFLAGS="-static"

make install-bin DESTDIR=/install_root PREFIX=/usr

# Flatcar uses /usr/bin as the canonical bindir; haproxy installs to
# /usr/sbin by default.
mkdir -p /install_root/usr/bin
mv /install_root/usr/sbin/haproxy /install_root/usr/bin/haproxy
rmdir /install_root/usr/sbin

chown -R "${export_user_group}" /install_root
