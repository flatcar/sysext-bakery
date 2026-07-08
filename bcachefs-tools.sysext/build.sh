#!/bin/ash
#
# Build script helper for the bcachefs-tools sysext.
# Runs inside an ephemeral Alpine container.
# Builds the bcachefs userspace utilities and exports them to a
# bind-mounted volume at /install_root.
#
set -euo pipefail

version="$1"
export_user_group="$2"

# Build deps. bcachefs-tools is a Rust+C project orchestrated by Make,
# linking against a fair pile of system libraries (sodium, urcu, blkid,
# keyutils, zlib, zstd, lz4, aio, udev, attr).
#
# We try a static build first (matches the scx.sysext precedent). If a
# given dep does not ship a static archive on Alpine, the corresponding
# *-static package add will fail loudly during CI and we can swap to a
# dynamic build that bundles the .so's under /usr/lib64.
apk add --no-cache \
  clang \
  clang-dev \
  clang-libclang \
  llvm \
  lld \
  bpftool \
  libbpf-dev \
  elfutils-dev \
  pkgconf \
  curl \
  git \
  make \
  gcc \
  musl-dev \
  linux-headers \
  ca-certificates \
  cargo \
  rust \
  zlib-dev          zlib-static \
  zstd-dev          zstd-static \
  lz4-dev           lz4-static \
  libsodium-dev     libsodium-static \
  liburcu-dev \
  util-linux-dev \
  keyutils-dev \
  libaio-dev \
  eudev-dev \
  attr-dev

cd /opt
git clone https://github.com/koverstreet/bcachefs-tools.git \
  --depth 1 --branch "${version}" --single-branch
cd /opt/bcachefs-tools

# Force static linking for Rust and C deps. Same env-var pattern as
# scx.sysext — CARGO_BUILD_TARGET forces the per-triple variants to take
# effect over the generic CARGO_* ones.
target="$(rustc -vV | sed -n 's/^host: //p')"
export CARGO_BUILD_TARGET="${target}"
TARGET="$(echo "${target}" | tr a-z- A-Z_)"
export CARGO_TARGET_${TARGET}_RUSTFLAGS="-C target-feature=+crt-static -C link-arg=-static"
export CARGO_TARGET_${TARGET}_PKG_CONFIG_ALL_STATIC=1

# Build + install. Flatcar's /usr/sbin is a symlink to /usr/bin, and a
# sysext shipping /usr/sbin would clobber the symlink at merge — so we
# redirect every sbin destination to /usr/bin. Skip the udev rules and
# initramfs hooks; the sysext only ships userspace tools.
make -j"$(nproc)" \
  PREFIX=/usr \
  bcachefs

make install \
  DESTDIR=/install_root \
  PREFIX=/usr \
  ROOT_SBINDIR=/usr/bin \
  PKGCONFIG_LIBDIR=/usr/lib/pkgconfig \
  INITRAMFS_DIR= \
  UDEVLIBDIR=

# Belt and suspenders: if any binary still landed under /usr/sbin
# (older Makefile variants), relocate it before it ships.
if [ -d /install_root/usr/sbin ]; then
  mkdir -p /install_root/usr/bin
  mv /install_root/usr/sbin/* /install_root/usr/bin/ 2>/dev/null || true
  rmdir /install_root/usr/sbin
fi

# Drop dev/man files — pure noise in a sysext.
rm -rf /install_root/usr/include \
       /install_root/usr/lib/pkgconfig \
       /install_root/usr/share/man \
       /install_root/usr/share/doc

chown -R "${export_user_group}" /install_root
chmod -R u+rwX,go+rX /install_root
