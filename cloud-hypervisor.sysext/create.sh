#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Cloud Hypervisor system extension.
#
# Ships the upstream statically linked cloud-hypervisor VMM and
# its ch-remote control tool.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "cloud-hypervisor" "cloud-hypervisor"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # Upstream publishes one static binary per architecture, suffixed
  # with -aarch64 for arm64 and unsuffixed for x86-64.
  local suffix=""
  case "${arch}" in
    arm64) suffix="-aarch64" ;;
  esac

  local base_url="https://github.com/cloud-hypervisor/cloud-hypervisor/releases/download/${version}"

  curl --remote-name -fsSL "${base_url}/cloud-hypervisor-static${suffix}"
  curl --remote-name -fsSL "${base_url}/ch-remote-static${suffix}"

  mkdir -p "${sysextroot}/usr/bin"
  install -m 0755 "cloud-hypervisor-static${suffix}" \
    "${sysextroot}/usr/bin/cloud-hypervisor"
  install -m 0755 "ch-remote-static${suffix}" \
    "${sysextroot}/usr/bin/ch-remote"
}
# --
