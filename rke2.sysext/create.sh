#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# RKE2, aka Rancher 2, sysext.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "rancher" "rke2"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"

  curl --parallel --fail --silent --show-error --location \
    --remote-name "https://github.com/rancher/rke2/releases/download/${version}/rke2.linux-${rel_arch}.tar.gz" \
    --remote-name "https://github.com/rancher/rke2/releases/download/${version}/sha256sum-${rel_arch}.txt"

  grep "rke2.linux-${rel_arch}.tar.gz$" "sha256sum-${rel_arch}.txt" | sha256sum -c -

  mkdir -p "${sysextroot}/usr/local"
  tar --force-local -xf "rke2.linux-${rel_arch}.tar.gz" -C "${sysextroot}/usr/local"
  rm "${sysextroot}/usr/local/bin/rke2-uninstall.sh"

  # Generate 2nd sysupdate config for only patchlevel upgrades.
  local sysupdate="$(get_optional_param "sysupdate" "false" "${@}")"
  if [[ ${sysupdate} == true ]] ; then
    local ver="$(echo "${version}" | sed 's/^\(v[0-9]\+\.[0-9]\+\).*/\1/')"
    _create_sysupdate "${extname}-${ver}"
    mv "${extname}-${ver}.conf" "${rundir}"
  fi
}
# --
