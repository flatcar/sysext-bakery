#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Keepalived system extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
    list_github_tags "acassen" "keepalived"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  local image="docker.io/${img_arch}/alpine:3.21"

  announce "Building keepalived $version for $arch"

  local user_group="$(id -u):$(id -g)"

  cp "${scriptroot}/keepalived.sysext/build.sh" .
  docker run --rm \
              -i \
              -v "$(pwd)":/install_root \
              --platform "linux/${img_arch}" \
              --pull always \
              ${image} \
                  /install_root/build.sh "${version}" "$user_group"

  # /usr/sbin is a symlink to /usr/bin on Flatcar.
  mv usr/sbin/keepalived usr/bin
  rmdir usr/sbin
  cp -aR usr "${sysextroot}"/
}
# --
