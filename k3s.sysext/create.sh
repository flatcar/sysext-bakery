#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# K3s system extension.
#

source "${scriptroot}/kubernetes.sysext/funcs.inc"

RELOAD_SERVICES_ON_MERGE="true"
EXTENSION_VERSION_MATCH_PATTERN='[.v0-9]+\+k3s[0-9]+'


# Get the latest k3s release for all supported major Kubernetes versions.
# Addresses https://github.com/flatcar/sysext-bakery/issues/213.
function list_latest_release() {
  local k8s_version
  local relcache

  relcache="$(mktemp)"
  trap "rm -f '${relcache}'" EXIT
  list_github_releases "k3s-io" "k3s" > "${relcache}"

  for k8s_version in $(kubernetes_list_latest_release); do
    cat "${relcache}" \
      | grep -F "${k8s_version}+k3s" \
      | sort -V \
      | tail -n1
  done
}
# --
#
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
    _create_sysupdate "${extname}" "${extname}-${ver}.@v-%a.raw" "${extname}" "${extname}" "${extname}-${ver}.conf"
    mv "${extname}-${ver}.conf" "${rundir}"
  fi
}
# --
