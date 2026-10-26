#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Uncloud extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "psviderski" "uncloud"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  local base_url="https://github.com/psviderski/uncloud/releases/download/${version}"
  curl --parallel --fail --silent --show-error --location \
        --remote-name "${base_url}/uncloudd_linux_${rel_arch}.tar.gz" \
        --remote-name "${base_url}/uc_linux_${rel_arch}.tar.gz"
  tar -xf "uncloudd_linux_${rel_arch}.tar.gz"
  tar -xf "uc_linux_${rel_arch}.tar.gz"

  mkdir -p "${sysextroot}/usr/bin"
  install -m 0755 uncloudd uc "${sysextroot}/usr/bin/"
}
# --
