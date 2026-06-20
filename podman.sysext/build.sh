#!/bin/ash
#
# Build script helper for the podman sysext.
# Runs inside an ephemeral Alpine container, builds podman and the
# companion binaries it depends on statically against musl, and exports
# everything to a bind-mounted volume at /install_root.
#
set -euo pipefail

podman_version="$1"
conmon_version="$2"
crun_version="$3"
runc_version="$4"
netavark_version="$5"
aardvark_version="$6"
slirp4netns_version="$7"
fuse_overlayfs_version="$8"
export_user_group="$9"

apk add --no-cache \
  autoconf \
  automake \
  bash \
  binutils \
  bsd-compat-headers \
  build-base \
  cargo \
  ca-certificates \
  curl \
  git \
  glib-dev \
  glib-static \
  go \
  gpgme-dev \
  libassuan-dev \
  libassuan-static \
  libcap-dev \
  libcap-static \
  libgpg-error-dev \
  libgpg-error-static \
  libseccomp-dev \
  libseccomp-static \
  libslirp-dev \
  libslirp-static \
  libtool \
  linux-headers \
  m4 \
  make \
  meson \
  ninja \
  pcre2-dev \
  pkgconf \
  python3 \
  rust \
  util-linux-dev \
  yajl-dev \
  yajl-static \
  zlib-dev \
  zlib-static

install_root=/install_root
mkdir -p "${install_root}/usr/bin" "${install_root}/usr/libexec/podman"
build_dir=/build
mkdir -p "${build_dir}"
cd "${build_dir}"

# Rust static linking: target current host triple.
rust_target="$(rustc -vV | sed -n 's/^host: //p')"
rust_target_env="$(echo "${rust_target}" | tr 'a-z-' 'A-Z_')"
export CARGO_BUILD_TARGET="${rust_target}"
export CARGO_TARGET_${rust_target_env}_RUSTFLAGS="-C target-feature=+crt-static"

# ---- conmon ---------------------------------------------------------------
echo ">>> Building conmon ${conmon_version}"
git clone --depth 1 --branch "${conmon_version}" \
  https://github.com/containers/conmon.git
( cd conmon
  make CFLAGS='-std=c99 -static' LDFLAGS='-static' bin/conmon
  install -m 0755 bin/conmon "${install_root}/usr/libexec/podman/conmon"
)

# ---- crun -----------------------------------------------------------------
echo ">>> Building crun ${crun_version}"
git clone --depth 1 --branch "${crun_version}" \
  https://github.com/containers/crun.git
( cd crun
  ./autogen.sh
  ./configure --disable-shared --enable-static --disable-systemd
  make LDFLAGS='-all-static'
  install -m 0755 crun "${install_root}/usr/bin/crun"
)

# ---- runc -----------------------------------------------------------------
echo ">>> Building runc ${runc_version}"
git clone --depth 1 --branch "${runc_version}" \
  https://github.com/opencontainers/runc.git
( cd runc
  make static BUILDTAGS='seccomp'
  install -m 0755 runc "${install_root}/usr/bin/runc"
)

# ---- netavark -------------------------------------------------------------
echo ">>> Building netavark ${netavark_version}"
git clone --depth 1 --branch "${netavark_version}" \
  https://github.com/containers/netavark.git
( cd netavark
  cargo build --release
  install -m 0755 "target/${rust_target}/release/netavark" \
    "${install_root}/usr/libexec/podman/netavark"
)

# ---- aardvark-dns ---------------------------------------------------------
echo ">>> Building aardvark-dns ${aardvark_version}"
git clone --depth 1 --branch "${aardvark_version}" \
  https://github.com/containers/aardvark-dns.git
( cd aardvark-dns
  cargo build --release
  install -m 0755 "target/${rust_target}/release/aardvark-dns" \
    "${install_root}/usr/libexec/podman/aardvark-dns"
)

# ---- slirp4netns ----------------------------------------------------------
echo ">>> Building slirp4netns ${slirp4netns_version}"
git clone --depth 1 --branch "${slirp4netns_version}" \
  https://github.com/rootless-containers/slirp4netns.git
( cd slirp4netns
  ./autogen.sh
  LDFLAGS='-static' ./configure
  make
  install -m 0755 slirp4netns "${install_root}/usr/bin/slirp4netns"
)

# ---- fuse-overlayfs -------------------------------------------------------
# fuse-overlayfs needs libfuse3 with static libs. Alpine does not ship a
# fuse3-static package, so build libfuse from source first.
echo ">>> Building libfuse for fuse-overlayfs"
git clone --depth 1 --branch fuse-3.16.2 \
  https://github.com/libfuse/libfuse.git
( cd libfuse
  mkdir build && cd build
  meson setup --default-library=static --prefix=/usr \
    -Dexamples=false -Dtests=false -Dutils=false ..
  ninja
  ninja install
)

echo ">>> Building fuse-overlayfs ${fuse_overlayfs_version}"
git clone --depth 1 --branch "${fuse_overlayfs_version}" \
  https://github.com/containers/fuse-overlayfs.git
( cd fuse-overlayfs
  ./autogen.sh
  LIBS='-lpthread' LDFLAGS='-static' ./configure
  make
  install -m 0755 fuse-overlayfs "${install_root}/usr/bin/fuse-overlayfs"
)

# ---- podman ---------------------------------------------------------------
echo ">>> Building podman ${podman_version}"
git clone --depth 1 --branch "${podman_version}" \
  https://github.com/containers/podman.git
( cd podman
  # Build statically. We exclude graphdrivers that need device-mapper or
  # btrfs userspace libraries and disable libsubid since musl does not
  # ship the shadow-utils subid C API. SELinux is also excluded because
  # Alpine does not provide libselinux.
  make BUILDTAGS='seccomp systemd exclude_graphdriver_devicemapper exclude_graphdriver_btrfs remote' \
       EXTRA_LDFLAGS='-linkmode external -extldflags "-static"' \
       CGO_ENABLED=1 \
       bin/podman bin/podman-remote bin/rootlessport bin/quadlet

  install -m 0755 bin/podman "${install_root}/usr/bin/podman"
  install -m 0755 bin/podman-remote "${install_root}/usr/bin/podman-remote"
  install -m 0755 bin/rootlessport "${install_root}/usr/libexec/podman/rootlessport"
  install -m 0755 bin/quadlet "${install_root}/usr/libexec/podman/quadlet"
)

# ---- containers.conf and friends -----------------------------------------
# Ship default helper-binary directories that point at our /usr/libexec
# locations so podman finds conmon, netavark, aardvark-dns and the
# rootlessport / quadlet helpers without further configuration.
mkdir -p "${install_root}/usr/share/containers"
cat >"${install_root}/usr/share/containers/containers.conf" <<'EOF'
[engine]
helper_binaries_dir = ["/usr/libexec/podman"]

[network]
network_backend = "netavark"

[containers]
init_path = "/usr/libexec/podman/catatonit"
EOF

chown -R "${export_user_group}" "${install_root}"
chmod -R u+rwX,go+rX "${install_root}"
