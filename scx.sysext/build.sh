#!/bin/bash
#
# Build script helper for scx sysext.
# This script runs inside an ephemeral Fedora container.
# It builds sched-ext schedulers and exports the binaries to a bind-mounted volume.
#
set -euo pipefail

version="$1"
export_user_group="$2"

dnf install -y \
  clang \
  llvm \
  lld \
  bpftool \
  libbpf-devel \
  elfutils-libelf-devel \
  zlib-devel \
  libzstd-devel \
  meson \
  cargo \
  rust \
  pkg-config \
  git \
  make \
  gcc \
  jq

cd /opt
git clone https://github.com/sched-ext/scx.git --depth 1 --branch ${version} --single-branch
cd /opt/scx

meson setup build \
  --prefix=/usr \
  --libdir=/usr/lib \
  -Dlibbpf_a=disabled \
  -Dbpftool=disabled \
  -Dopenrc=disabled \
  -Dsystemd=disabled

meson compile -C build
DESTDIR=/install_root meson install -C build

# Remove unnecessary files (keep only binaries)
rm -rf /install_root/usr/share/doc \
       /install_root/usr/share/licenses \
       /install_root/usr/share/scx \
       /install_root/usr/lib/systemd \
       /install_root/etc

chown -R "$export_user_group" /install_root
