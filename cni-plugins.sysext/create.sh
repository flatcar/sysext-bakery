#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# CNI reference plugins system extension.
#
# Ships the upstream containernetworking/plugins binaries (bridge, host-local,
# portmap, firewall, loopback, macvlan, ptp, …) under /usr/libexec/cni, the
# same location nerdctl.sysext uses for its bundled copy. Upstream's de-facto
# default is /opt/cni/bin, but on Flatcar /opt is expected to be writable and a
# sysext would make it read-only, so consumers are pointed at /usr instead (see
# docs/cni-plugins.md). There is no service; the binaries are invoked by the
# CNI consumer.
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
  mkdir -p "${sysextroot}/usr/libexec/cni"
  tar --force-local -xzf "${tarball}" -C "${sysextroot}/usr/libexec/cni"
}
# --
