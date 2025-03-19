#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Nerdcuddle sysext.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
    list_github_releases "containerd" "nerdctl"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local cni="$(get_optional_param "with-cni" "" "$@")"
  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"

  curl --remote-name -fsSL \
    "https://github.com/containerd/nerdctl/releases/download/${version}/nerdctl-${version#v}-linux-${rel_arch}.tar.gz"

  if [[ -n $cni ]] ; then
    curl --remote-name -fsSL \
        "https://github.com/containernetworking/plugins/releases/download/${cni}/cni-plugins-linux-${rel_arch}-${cni}.tgz"
  fi

  mkdir -p "${sysextroot}/usr/bin"
  tar --force-local -xzf "nerdctl-${version#v}-linux-${rel_arch}.tar.gz" -C "${sysextroot}/usr/bin"

  if [[ -n $cni ]] ; then
    mkdir -p "${sysextroot}/usr/libexec/cni"
    tar --force-local -xzf "cni-plugins-linux-${rel_arch}-${cni}.tgz" -C "${sysextroot}/usr/libexec/cni"
    echo "${cni}"> "${sysextroot}/usr/share/nerdctl/nerdctl-cni-version"
  else
    # Remove CNI config files and systemd tmpfiles generators
    rm -rf "${sysextroot}/usr/share/nerdctl/" \
           "${sysextroot}usr/lib/tmpfiles.d"
  fi
}
# --

function populate_sysext_root_options() {
  echo "  --with-cni <version> : Also ship CNI plugin <version in the sysext."
  echo "                  For a list of CNI plugin versions, please refer to"
  echo "                  https://github.com/containernetworking/plugins/releases"
}
# --
