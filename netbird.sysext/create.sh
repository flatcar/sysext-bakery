#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# NetBird extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  # NetBird publishes release candidates (e.g. v0.75.0-rc.6) as regular
  # GitHub releases without the prerelease flag, so only accept stable
  # vX.Y.Z tags to keep "latest" from resolving to an RC.
  list_github_releases "netbirdio" "netbird" \
      | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$'
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  local relver="${version#v}"

  curl --parallel --fail --silent --show-error --location \
    --remote-name "https://github.com/netbirdio/netbird/releases/download/${version}/netbird_${relver}_linux_${rel_arch}.tar.gz" \
    --remote-name "https://github.com/netbirdio/netbird/releases/download/${version}/netbird_${relver}_checksums.txt"

  grep "netbird_${relver}_linux_${rel_arch}.tar.gz" "netbird_${relver}_checksums.txt" \
    | sha256sum --check -

  mkdir -p "${sysextroot}/usr/bin"
  tar --force-local -xf "netbird_${relver}_linux_${rel_arch}.tar.gz" -C "${sysextroot}/usr/bin" netbird
  chmod +x "${sysextroot}/usr/bin/netbird"
}
# --
