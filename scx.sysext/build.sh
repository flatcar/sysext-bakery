#!/bin/ash
#
# Build script helper for scx sysext.
# This script runs inside an ephemeral Alpine container.
# It builds sched-ext schedulers and exports the binaries to a bind-mounted volume.
#
set -euo pipefail

version="$1"
export_user_group="$2"

apk add --no-cache \
  clang \
  clang-dev \
  clang-libclang \
  llvm \
  lld \
  bpftool \
  libbpf-dev \
  elfutils-dev \
  zlib-dev \
  zstd-dev \
  libseccomp-dev \
  cargo \
  rust \
  pkgconf \
  curl \
  git \
  make \
  gcc \
  musl-dev \
  linux-headers \
  jq \
  ca-certificates \
  pax-utils

cd /opt
git clone https://github.com/sched-ext/scx.git --depth 1 --branch ${version} --single-branch
cd /opt/scx

# Force static linking for Rust and C dependencies.
target="$(rustc -vV | sed -n 's/^host: //p')"
export CARGO_BUILD_TARGET="${target}"
export RUSTFLAGS="-C target-feature=+crt-static"
export PKG_CONFIG_ALL_STATIC=1
export LIBBPF_SYS_STATIC=1
export RUSTFLAGS="${RUSTFLAGS} -C link-arg=-lzstd"

# Ensure libz static is available for fully static linking.
if [ ! -f /usr/lib/libz.a ] && [ ! -f /lib/libz.a ] && [ ! -f /usr/local/lib/libz.a ]; then
  zlib_version="1.3.1"
  workdir="/tmp/zlib-${zlib_version}"
  zlib_url="https://zlib.net/zlib-${zlib_version}.tar.gz"
  if ! curl -fsSL "${zlib_url}" -o /tmp/zlib.tar.gz; then
    curl -fsSL "https://zlib.net/fossils/zlib-${zlib_version}.tar.gz" -o /tmp/zlib.tar.gz
  fi
  tar -C /tmp -xf /tmp/zlib.tar.gz
  cd "${workdir}"
  ./configure --static
  make -j"$(nproc)"
  make install
  cd /opt/scx
  export LIBRARY_PATH="/usr/local/lib:${LIBRARY_PATH:-}"
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
fi

# Ensure libzstd static is available for libelf static linking.
if [ ! -f /usr/lib/libzstd.a ] && [ ! -f /lib/libzstd.a ] && [ ! -f /usr/local/lib/libzstd.a ]; then
  zstd_version="1.5.7"
  workdir="/tmp/zstd-${zstd_version}"
  curl -fsSL "https://github.com/facebook/zstd/releases/download/v${zstd_version}/zstd-${zstd_version}.tar.gz" -o /tmp/zstd.tar.gz
  tar -C /tmp -xf /tmp/zstd.tar.gz
  cd "${workdir}"
  make -j"$(nproc)"
  make install PREFIX=/usr/local
  cd /opt/scx
  export LIBRARY_PATH="/usr/local/lib:${LIBRARY_PATH:-}"
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
fi

# Build Rust schedulers (includes scx_bpfland and others)
cargo build --release

# Verify binaries are fully static (no NEEDED entries).
for bin in target/release/scx_*; do
  if [ -x "${bin}" ]; then
    needed="$(scanelf --needed --nobanner -F '%N' "${bin}")"
    if [ -n "${needed}" ]; then
      echo "ERROR: ${bin} is not fully static (NEEDED: ${needed})"
      exit 1
    fi
  fi
done

# Install binaries (only executables, not .d dependency files)
mkdir -p /install_root/usr/bin
find target/release -maxdepth 1 -name 'scx_*' -type f -executable -exec cp {} /install_root/usr/bin/ \;

chown -R "$export_user_group" /install_root
# Ensure host user can always read/delete build artifacts on the bind mount.
chmod -R u+rwX,go+rX /install_root
