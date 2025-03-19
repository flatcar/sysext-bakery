#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Tailscale extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "tailscale" "tailscale"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  curl --parallel --fail --silent --show-error --location \
        --remote-name "https://pkgs.tailscale.com/stable/tailscale_${version#v}_${rel_arch}.tgz"
  tar --force-local --strip-components=1 -xf "tailscale_${version#v}_${rel_arch}.tgz"

  mkdir -p "${sysextroot}/usr/bin"
  mkdir -p "${sysextroot}/usr/lib/systemd/system/"
  mkdir -p "${sysextroot}/usr/share/tailscale"

  cp -a tailscale tailscaled "${sysextroot}/usr/bin/"
  cp systemd/tailscaled.service "${sysextroot}/usr/lib/systemd/system/"
  cp systemd/tailscaled.defaults "${sysextroot}/usr/share/tailscale/"

  # Can't use /usr/sbin 
  sed -i 's,/usr/sbin/tailscaled,/usr/bin/tailscaled,g' \
    "${sysextroot}/usr/lib/systemd/system/tailscaled.service"
}
# --
