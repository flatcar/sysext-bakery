#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  curl -fsSL --retry-delay 1 --retry 60 \
    --retry-connrefused --retry-max-time 60 --connect-timeout 20 \
    https://api.releases.hashicorp.com/v1/releases/consul?limit=20 \
  | jq -r '.[] | select(.is_prerelease == false)
               | select(.license_class == "oss")
               | .version' \
  | sort -Vr
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch
  rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  curl -fsSLZO --retry-delay 1 --retry 60 \
    --retry-connrefused --retry-max-time 60 --connect-timeout 20 \
    "https://releases.hashicorp.com/consul/${version}/consul_${version}_linux_${rel_arch}.zip"
  # Unzip the binary
  mkdir -p "${sysextroot}/usr/bin"
  unzip -q "consul_${version}_linux_${rel_arch}.zip"
  install -m 0755 consul "${sysextroot}/usr/bin"
}
# --
