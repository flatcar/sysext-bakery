#!/bin/ash
#
# Build script helper for the haproxy sysext.
# Runs inside an ephemeral alpine container. Builds a static haproxy
# against musl with a broad feature set and installs the binary to a
# bind-mounted volume.
#
set -euo pipefail

version="$1"
export_user_group="$2"

branch="$(echo "${version}" | awk -F. '{print $1"."$2}')"

apk --no-cache add \
  build-base \
  ca-certificates \
  curl \
  libcap-static \
  linux-headers \
  lua5.4-dev \
  openssl-dev \
  openssl-libs-static \
  pcre2-dev \
  zlib-dev \
  zlib-static

src=/tmp/haproxy-build
mkdir -p "${src}"
cd "${src}"

curl -fsSLO "https://www.haproxy.org/download/${branch}/src/haproxy-${version}.tar.gz"
curl -fsSLO "https://www.haproxy.org/download/${branch}/src/haproxy-${version}.tar.gz.sha256"
sha256sum -c "haproxy-${version}.tar.gz.sha256"

tar -xf "haproxy-${version}.tar.gz"
cd "haproxy-${version}"

make -j"$(nproc)" \
  TARGET=linux-musl \
  USE_OPENSSL=1 \
  USE_QUIC=1 USE_QUIC_OPENSSL_COMPAT=1 \
  USE_PCRE2=1 USE_PCRE2_JIT=1 \
  USE_ZLIB=1 \
  USE_LUA=1 LUA_LIB_NAME=lua5.4 \
    LUA_INC=/usr/include/lua5.4 \
    LUA_LDFLAGS='-L/usr/lib/lua5.4 -l:liblua.a' \
  USE_THREAD=1 USE_PTHREAD_EMULATION=1 \
  USE_TFO=1 USE_NS=1 USE_GETADDRINFO=1 \
  USE_LINUX_TPROXY=1 USE_LINUX_SPLICE=1 USE_LINUX_CAP=1 \
  USE_PROMEX=1 USE_CRYPT_H=1 \
  USE_TRANSPARENT=1 USE_ACCEPT4=1 USE_PRCTL=1 \
  CFLAGS='-static -s' \
  LDFLAGS='-static -lc -ldl' \
  THREAD_LDFLAGS='-lpthread'

make install-bin DESTDIR=/install_root PREFIX=/usr SBINDIR=/usr/bin

rm -rf /install_root/usr/share /install_root/usr/doc /install_root/etc

chown -R "${export_user_group}" /install_root
