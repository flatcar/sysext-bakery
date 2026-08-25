#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Prometheus Node Exporter system extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "prometheus" "node_exporter"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  local raw_version="${version#v}"
  local tarball="node_exporter-${raw_version}.linux-${rel_arch}.tar.gz"

  curl --parallel --fail --silent --show-error --location \
    --remote-name "https://github.com/prometheus/node_exporter/releases/download/${version}/${tarball}"

  tar --force-local --strip-components=1 -xf "${tarball}"

  mkdir -p "${sysextroot}/usr/bin"
  cp -a node_exporter "${sysextroot}/usr/bin/"
}
# --
