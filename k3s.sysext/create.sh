#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# K3s system extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "k3s-io" "k3s"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local suffix=""
  if [[ $arch == arm64 ]] ; then
    suffix="-arm64"
  fi

  curl -o k3s -fsSL "https://github.com/k3s-io/k3s/releases/download/${version}/k3s${suffix}"
  mkdir -p "${sysextroot}/usr/local/bin/"
  cp -a k3s "${sysextroot}/usr/local/bin/"
  chmod +x "${sysextroot}/usr/local/bin/k3s"

  cd "${sysextroot}/usr/local/bin"
  ln -s ./k3s kubectl
  ln -s ./k3s ctr
  ln -s ./k3s crictl

  # Generate 2nd sysupdate config for only patchlevel upgrades.
  local sysupdate="$(get_optional_param "sysupdate" "false" "${@}")"
  if [[ ${sysupdate} == true ]] ; then
    local ver="$(echo "${version}" | sed 's/^\(v[0-9]\+\.[0-9]\+\).*/\1/')"
    _create_sysupdate "${extname}-${ver}" "${extname}-${ver}.@v-%a.raw" "${extname}" "${extname}"
    mv "${extname}-${ver}.conf" "${rundir}"
  fi
}
# --
