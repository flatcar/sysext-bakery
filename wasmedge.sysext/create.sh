#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# The WasmEdge sysext.
#

RELOAD_SERVICES_ON_MERGE="fales"

function list_available_versions() {
  list_github_releases "WasmEdge" "WasmEdge"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "x86_64" "$arch")"
  local rel_arch="$(arch_transform "arm64" "aarch64" "$rel_arch")"

  curl --parallel --fail --silent --show-error --location \
       --remote-name "https://github.com/WasmEdge/WasmEdge/releases/download/${version}/WasmEdge-${version}-ubuntu20.04_${rel_arch}.tar.gz"
  tar --force-local -xf "WasmEdge-${version}-ubuntu20.04_${rel_arch}.tar.gz"

  mkdir -p "${sysextroot}/usr/bin"
  mkdir -p "${sysextroot}/usr/lib"

  local prefix="."
  if semver_lower "${version}" "0.15.0" ; then
    local prefix="WasmEdge-${version}-Linux"
  fi

  cp -a "${prefix}"/bin/* "${sysextroot}"/usr/bin/
  cp -a "${prefix}"/lib/* "${sysextroot}"/usr/lib/
}
# --
