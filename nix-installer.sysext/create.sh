#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# The Nix INstaller System Extension
# Note that this extension eases the _installation_ of Nix on Flatcar; it does not itself contain a fully functional Nix.
# This is mostly because of Nix requiring to reside in the '/nix' top-level directory, and the inability of Nix to handle immutable, read-only stores.

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  curl -sSL 'https://nix-releases.s3.amazonaws.com/?delimiter=/&prefix=nix/' \
    | grep -Po '(?<=<Prefix>nix/nix-)[^/<]+' \
    | sort -V -r
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "x86_64" "$arch")"
  rel_arch="$(arch_transform "arm64" "aarch64" "$rel_arch")"

  # Fetch release tarball and verify checksum

  local url="https://releases.nixos.org/nix/nix-${version}"
  local tarball="nix-${version}-${rel_arch}-linux.tar.xz"
  local subdir="${tarball%.tar.xz}"

  curl -sSL --remote-name "${url}/${tarball}"
  curl -sSL --remote-name "${url}/${tarball}.sha256"

  local shasum_exp shasum_real
  shasum_exp="$(cat "${tarball}.sha256")"
  shasum_real="$(sha256sum "${tarball}" | cut -d' ' -f1)"

  if [[ "${shasum_real}" != "${shasum_exp}" ]] ; then
    echo "ERROR: NixOS tarball '${tarball}' has mis-matching SHA256SUM."
    echo "Expected: '${shasum_exp}' (from '${tarball}.sha256')"
    echo "Got     : '${shasum_real}'"
    exit 1
  fi

  tar xJf "${tarball}"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"
  local image="docker.io/alpine:latest"
  local user_group="$(id -u):$(id -g)"

  mkdir -p dest

  cp "${scriptroot}/nix-installer.sysext/build.sh" .
  docker run --rm \
    -i \
    -v "$(pwd)/build.sh":/build.sh \
    -v "$(pwd)/${subdir}":/install_src \
    -v "$(pwd)/dest":/install_dest \
    --platform "linux/${img_arch}" \
    ${image} \
        /build.sh "${version}" "$user_group"

     cp -aR dest/usr "${sysextroot}"
}
# --
# TODO:
# provide installer
# user=core
# group=core
# cp -a /usr/nix/nixroot/ /nix
# chown -R $user:$group -R /nix
# cp -a /usr/nix/nixhome/.* /home/$user
# echo "source /home/$user/.nix-profile/etc/profile.d/nix.sh" > /home/$user/.bashrc

