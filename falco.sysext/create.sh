#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Falco system extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "falcosecurity" "falco"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # The release uses different arch identifiers
  local rel_arch="$(arch_transform 'x86-64' 'x86_64' "$arch")"
  rel_arch="$(arch_transform 'arm64' 'aarch64' "$rel_arch")"

  mkdir -p "${sysextroot}"/usr/share/falco/etc/

  curl --remote-name \
       -fsSL "https://download.falco.org/packages/bin/${rel_arch}/falco-${version}-${rel_arch}.tar.gz"

  tar --strip-components 1 -xzf "falco-${version}-${rel_arch}.tar.gz"

  cp -aR etc/falco \
        etc/falcoctl \
     "${sysextroot}/usr/share/falco/etc/"

  cp -aR usr/ "${sysextroot}/"
}
# --
