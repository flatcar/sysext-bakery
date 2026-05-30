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
  zlib-static \
  zstd-dev \
  zstd-static \
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

# Force static linking for Rust and C dependencies. Since we set CARGO_BUILD_TARGET
# below, cargo uses CARGO_TARGET_<TRIPLE>_* env vars in preference to generic ones,
# so we have to set the prefixed forms.
target="$(rustc -vV | sed -n 's/^host: //p')"
export CARGO_BUILD_TARGET="${target}"
TARGET="$(echo "${target}" | tr a-z- A-Z_)"
export CARGO_TARGET_${TARGET}_RUSTFLAGS="-C target-feature=+crt-static -lz -lzstd -lpthread -L /usr/lib -C link-arg=-Wl,-static"
export CARGO_TARGET_${TARGET}_PKG_CONFIG_ALL_STATIC=1
export CARGO_TARGET_${TARGET}_LIBBPF_SYS_STATIC=1

# Build Rust schedulers and tools (scx_* schedulers, scxtop, scxcash, ...).
cargo build --release

# Install schedulers and tools (only executables, not .d dependency files).
mkdir -p /install_root/usr/bin
find "target/${target}/release" -maxdepth 1 -name 'scx*' -type f -executable -exec cp \{\} /install_root/usr/bin/ \;

chown -R "$export_user_group" /install_root
# Ensure host user can always read/delete build artifacts on the bind mount.
chmod -R u+rwX,go+rX /install_root
