#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# CNI reference plugins system extension.
#
# Ships the upstream containernetworking/plugins binaries (bridge, host-local,
# portmap, firewall, loopback, macvlan, ptp, …) under /opt/cni/bin — the
# default plugin directory searched by Nomad (cni_path) and usable by any CNI
# runtime (Consul Connect, container runtimes, …). There is no service; the
# binaries are invoked by the CNI consumer.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "containernetworking" "plugins"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # Upstream artefact names use "amd64" / "arm64".
  local rel_arch
  rel_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"

  local tarball="cni-plugins-linux-${rel_arch}-${version}.tgz"
  local base_url="https://github.com/containernetworking/plugins/releases/download/${version}"

  # Upstream publishes a .sha256 alongside each tarball.
  curl --remote-name -fsSL "${base_url}/${tarball}"
  curl --remote-name -fsSL "${base_url}/${tarball}.sha256"
  sha256sum -c "${tarball}.sha256"

  # The tarball expands flat (bridge, host-local, portmap, …) into the target.
  mkdir -p "${sysextroot}/opt/cni/bin"
  tar --force-local -xzf "${tarball}" -C "${sysextroot}/opt/cni/bin"
}
# --
