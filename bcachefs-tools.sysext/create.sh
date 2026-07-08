#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# bcachefs-tools system extension.
# Provides bcachefs userspace utilities (bcachefs, mkfs.bcachefs,
# fsck.bcachefs, mount.bcachefs, ...).
#
# The bcachefs kernel module itself is shipped separately by the
# bcachefs-kmod sysext (one build per Flatcar kernel version).

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  # Upstream publishes git tags (vX.Y.Z) but not GitHub Releases,
  # so we have to read tags rather than releases.
  list_github_tags "koverstreet" "bcachefs-tools"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  local image="docker.io/alpine:latest"

  announce "Building bcachefs-tools ${version} for ${arch}"

  local user_group="$(id -u):$(id -g)"

  cp "${scriptroot}/bcachefs-tools.sysext/build.sh" .

  docker run --rm \
    -i \
    -v "$(pwd)":/install_root \
    --platform "linux/${img_arch}" \
    --pull always \
    ${image} \
      /install_root/build.sh "${version}" "${user_group}"

  cp -aR usr "${sysextroot}"/
}
# --
