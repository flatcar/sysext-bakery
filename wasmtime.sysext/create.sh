#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Wasmtime sysext.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "bytecodealliance" "wasmtime"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "x86_64" "$arch")"
  local rel_arch="$(arch_transform "arm64" "aarch64" "$rel_arch")"

  curl --parallel --fail --silent --show-error --location \
       --remote-name "https://github.com/bytecodealliance/wasmtime/releases/download/${version}/wasmtime-${version}-${rel_arch}-linux.tar.xz"
  tar --force-local -xf "wasmtime-${version}-${rel_arch}-linux.tar.xz"

  mkdir -p "${sysextroot}"/usr/bin
  cp -a "wasmtime-${version}-${rel_arch}-linux/wasmtime" "${sysextroot}"/usr/bin
}
# --
