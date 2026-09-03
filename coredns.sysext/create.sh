#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# CoreDNS system extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  # CoreDNS also carries pre-1.0 tags like "v011" that sort above "v1.14.7"
  # and predate the current release archives. Keep semver tags only.
  list_github_releases "coredns" "coredns" \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$'
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # Release tags are "vX.Y.Z" but the release archives drop the leading "v".
  local relver="${version#v}"

  local rel_arch
  rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"

  local tarball="coredns_${relver}_linux_${rel_arch}.tgz"
  local baseurl="https://github.com/coredns/coredns/releases/download/v${relver}"

  announce "Fetching CoreDNS ${version} for ${arch}"
  curl -fsSLZ --retry-delay 1 --retry 60 \
    --retry-connrefused --retry-max-time 60 --connect-timeout 20 \
    -O "${baseurl}/${tarball}" \
    -O "${baseurl}/${tarball}.sha256"

  announce "Verifying ${tarball}"
  sha256sum --check --strict "${tarball}.sha256"

  tar --force-local -xf "${tarball}" coredns
  mkdir -p "${sysextroot}/usr/bin"
  install -m 0755 coredns "${sysextroot}/usr/bin"
}
# --
