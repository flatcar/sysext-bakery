#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Kubernetes system extension.
#

source "${scriptroot}/kubernetes.sysext/funcs.inc"

RELOAD_SERVICES_ON_MERGE="true"

# We overwrite this library function and return a list of all latest patch levels
# of all supported release branches.
function list_latest_release() {
  kubernetes_list_latest_release "${@}"
}
# --

function list_available_versions() {
  kubernetes_list_available_versions "${@}"
}
# --

function populate_sysext_root_options() {
  echo "  --cni-version <version> : Include CNI plugin <version> instead of latest."
  echo "                            For a list of versions please refer to:"
  echo "                    https://github.com/containernetworking/plugins/releases"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local cni_version="$(get_optional_param "cni-version" "" "$@")"
  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"

  mkdir -p "${sysextroot}/usr/bin"

  curl --parallel --fail --silent --show-error --location \
    --output "${sysextroot}/usr/bin/kubectl" "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubectl" \
    --output kubectl.sha256 "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubectl.sha256" \
    --output "${sysextroot}/usr/bin/kubeadm" "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubeadm" \
    --output kubeadm.sha256 "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubeadm.sha256" \
    --output "${sysextroot}/usr/bin/kubelet" "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubelet"\
    --output kubelet.sha256 "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubelet.sha256"

  for bin in kubectl kubeadm kubelet; do
    echo "Verifying ${bin} checksum..."
    echo "$(cat "${bin}.sha256")  ${sysextroot}/usr/bin/${bin}" | shasum -a 256 --check
  done

  chmod +x "${sysextroot}/usr/bin/"*

  # An empty --cni-version resolves to the latest upstream release. Keep the
  # plugins at /usr/local/bin/cni, where this extension has always put them, so
  # existing kubelet configuration keeps working.
  install_cni_plugins "${sysextroot}" "${arch}" "${cni_version}" "usr/local/bin/cni"
  announce "Using CNI version '${CNI_PLUGINS_VERSION}'"

  mkdir -p "${sysextroot}/usr/local/share/"
  echo "${version}" > "${sysextroot}/usr/local/share/kubernetes-version"
  echo "${CNI_PLUGINS_VERSION}" > "${sysextroot}/usr/local/share/kubernetes-cni-version"

  mkdir -p "${sysextroot}/usr/libexec/kubernetes/kubelet-plugins/volume/"
  # /var/kubernetes/... will be created at runtime by the kubelet unit.
  ln -sf "/var/kubernetes/kubelet-plugins/volume/exec" "${sysextroot}/usr/libexec/kubernetes/kubelet-plugins/volume/exec"

  # Generate 2nd sysupdate config for only patchlevel upgrades.
  local sysupdate="$(get_optional_param "sysupdate" "false" "${@}")"
  if [[ ${sysupdate} == true ]] ; then
    local majorver="$(echo "${version}" | sed 's/^\(v[0-9]\+\.[0-9]\+\).*/\1/')"
    _create_sysupdate "${extname}" "${extname}-${majorver}.@v-%a.raw" "${extname}" "${extname}" "${extname}-${majorver}.conf"
    mv "${extname}-${majorver}.conf" "${rundir}"
  fi
}
# --
