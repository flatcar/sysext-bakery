#!/bin/bash
#
# Build script helper for the haproxy sysext. Runs inside an ephemeral
# debian:bookworm-slim container. Builds haproxy from upstream source
# with a broad feature set, installs the binary, then uses
# /tools/flix.sh to bundle its runtime library deps and patch RPATH.
#
set -euo pipefail

version="$1"
export_user_group="$2"

branch="$(echo "${version}" | awk -F. '{print $1"."$2}')"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential \
  ca-certificates \
  curl \
  libcap-dev \
  liblua5.4-dev \
  libpcre2-dev \
  libssl-dev \
  patchelf \
  pkg-config \
  zlib1g-dev

src=/tmp/haproxy-build
mkdir -p "${src}"
cd "${src}"

curl -fsSLO "https://www.haproxy.org/download/${branch}/src/haproxy-${version}.tar.gz"
curl -fsSLO "https://www.haproxy.org/download/${branch}/src/haproxy-${version}.tar.gz.sha256"
sha256sum -c "haproxy-${version}.tar.gz.sha256"

tar -xf "haproxy-${version}.tar.gz"
cd "haproxy-${version}"

lua_inc="$(pkg-config --variable=includedir lua5.4)"
lua_lib="$(pkg-config --variable=libdir lua5.4)"

make -j"$(nproc)" \
  TARGET=linux-glibc \
  USE_OPENSSL=1 \
  USE_QUIC=1 USE_QUIC_OPENSSL_COMPAT=1 \
  USE_PCRE2=1 USE_PCRE2_JIT=1 \
  USE_ZLIB=1 \
  USE_LUA=1 LUA_LIB_NAME=lua5.4 LUA_LIB="${lua_lib}" LUA_INC="${lua_inc}" \
  USE_THREAD=1 \
  USE_TFO=1 USE_NS=1 USE_GETADDRINFO=1 \
  USE_LINUX_TPROXY=1 USE_LINUX_SPLICE=1 USE_LINUX_CAP=1 \
  USE_PROMEX=1 USE_BACKTRACE=1 USE_LIBCRYPT=1 \
  USE_TRANSPARENT=1 USE_ACCEPT4=1 USE_PRCTL=1

# Install to /usr/bin so flix.sh picks it up at the same path.
make install-bin DESTDIR=/ PREFIX=/usr SBINDIR=/usr/bin

cd /install_root
/tools/flix.sh / haproxy /usr/bin/haproxy

chown -R "${export_user_group}" /install_root
