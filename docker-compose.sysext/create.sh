#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Docker compose system extension.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "docker" "compose" \
    | sed 's/^v//'
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # The github release uses different arch identifiers
  local rel_arch="$(arch_transform 'x86-64' 'x86_64' "$arch")"
  rel_arch="$(arch_transform 'arm64' 'aarch64' "$rel_arch")"

  mkdir -p "${sysextroot}/usr/local/lib/docker/cli-plugins"
  curl -o "${sysextroot}/usr/local/lib/docker/cli-plugins/docker-compose" \
    -fsSL "https://github.com/docker/compose/releases/download/v${version}/docker-compose-linux-${rel_arch}"
  chmod +x "${sysextroot}/usr/local/lib/docker/cli-plugins/docker-compose"
}
# --
