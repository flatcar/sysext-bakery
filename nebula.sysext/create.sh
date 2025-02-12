#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Nebula sysext.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "slackhq" "nebula"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"

  curl --parallel --fail --silent --show-error --location \
    --remote-name "https://github.com/slackhq/nebula/releases/download/${version}/nebula-linux-${rel_arch}.tar.gz" \
    --remote-name "https://github.com/slackhq/nebula/releases/download/${version}/SHASUM256.txt"

  grep "nebula-linux-${rel_arch}.tar.gz$" SHASUM256.txt | sha256sum -c -

  mkdir -p "${sysextroot}/usr/bin"
  tar --force-local -xf "nebula-linux-${rel_arch}.tar.gz" -C "${sysextroot}/usr/bin"
  chmod +x "${sysextroot}/usr/bin/nebula" \
           "${sysextroot}/usr/bin/nebula-cert"
}
# --
