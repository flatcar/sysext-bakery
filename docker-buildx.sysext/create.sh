#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Docker buildx system extension.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "docker" "buildx" \
    | sed 's/^v//'
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # The github release uses different arch identifiers
  local rel_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  rel_arch="$(arch_transform 'arm64' 'arm64' "$rel_arch")"

  mkdir -p "${sysextroot}/usr/local/lib/docker/cli-plugins"
  curl -o "${sysextroot}/usr/local/lib/docker/cli-plugins/docker-buildx" \
    -fsSL "https://github.com/docker/buildx/releases/download/v${version}/buildx-v${version}.linux-${rel_arch}"
  chmod +x "${sysextroot}/usr/local/lib/docker/cli-plugins/docker-buildx"
}
# --
