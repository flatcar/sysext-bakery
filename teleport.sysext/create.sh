#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Teleport sysext.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "gravitational" "teleport"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch
  rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  curl -fsSL --retry-delay 1 --retry 60 \
    --retry-connrefused --retry-max-time 60 --connect-timeout 20 \
    "https://cdn.teleport.dev/teleport-${version}-linux-${rel_arch}-bin.tar.gz" \
    | tar --force-local --strip-components=1 -xz

  mkdir -p "${sysextroot}/usr/bin"
  install -m 0755 teleport tctl tsh "${sysextroot}/usr/bin/"
}
# --
