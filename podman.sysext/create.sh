#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Podman system extension.
#
# Builds podman and its required companion binaries (conmon, crun,
# runc, netavark, aardvark-dns, slirp4netns, fuse-overlayfs) from
# source inside an ephemeral Alpine container. All binaries are
# statically linked against musl so the sysext is self-contained.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "containers" "podman"
}
# --

function populate_sysext_root_options() {
  echo "  --conmon <version>         : conmon version to bundle (default: v2.1.13)."
  echo "  --crun <version>           : crun version to bundle (default: 1.21)."
  echo "  --runc <version>           : runc version to bundle (default: v1.2.6)."
  echo "  --netavark <version>       : netavark version to bundle (default: v1.14.1)."
  echo "  --aardvark-dns <version>   : aardvark-dns version to bundle (default: v1.14.0)."
  echo "  --slirp4netns <version>    : slirp4netns version to bundle (default: v1.3.3)."
  echo "  --fuse-overlayfs <version> : fuse-overlayfs version to bundle (default: v1.14)."
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local conmon_version="$(get_optional_param "conmon" "v2.1.13" "$@")"
  local crun_version="$(get_optional_param "crun" "1.21" "$@")"
  local runc_version="$(get_optional_param "runc" "v1.2.6" "$@")"
  local netavark_version="$(get_optional_param "netavark" "v1.14.1" "$@")"
  local aardvark_version="$(get_optional_param "aardvark-dns" "v1.14.0" "$@")"
  local slirp4netns_version="$(get_optional_param "slirp4netns" "v1.3.3" "$@")"
  local fuse_overlayfs_version="$(get_optional_param "fuse-overlayfs" "v1.14" "$@")"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  local image="docker.io/alpine:3.21"

  announce "Building podman ${version} for ${arch}"

  local user_group="$(id -u):$(id -g)"

  cp "${scriptroot}/podman.sysext/build.sh" .

  docker run --rm \
    -i \
    -v "$(pwd)":/install_root \
    --platform "linux/${img_arch}" \
    --pull always \
    "${image}" \
    /install_root/build.sh \
      "${version}" \
      "${conmon_version}" \
      "${crun_version}" \
      "${runc_version}" \
      "${netavark_version}" \
      "${aardvark_version}" \
      "${slirp4netns_version}" \
      "${fuse_overlayfs_version}" \
      "${user_group}"

  cp -aR usr "${sysextroot}/"
}
# --
