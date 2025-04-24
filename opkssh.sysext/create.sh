#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# opkssh extension.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "openpubkey" "opkssh"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  curl --parallel --fail --silent --show-error --location \
        --remote-name "https://github.com/openpubkey/opkssh/releases/download/${version}/opkssh-linux-${rel_arch}"

  mkdir -p "${sysextroot}/usr/local/bin"

  cp opkssh-linux-${rel_arch} "${sysextroot}/usr/local/bin/opkssh"
  chmod 755 "${sysextroot}/usr/local/bin/opkssh"
}
# --
