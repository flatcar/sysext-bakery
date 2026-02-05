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
  git \
  make \
  gcc \
  musl-dev \
  linux-headers \
  jq

cd /opt
git clone https://github.com/sched-ext/scx.git --depth 1 --branch ${version} --single-branch
cd /opt/scx

# Build Rust schedulers (includes scx_bpfland and others)
cargo build --release

# Install binaries (only executables, not .d dependency files)
mkdir -p /install_root/usr/bin
find target/release -maxdepth 1 -name 'scx_*' -type f -executable -exec cp {} /install_root/usr/bin/ \;

chown -R "$export_user_group" /install_root
