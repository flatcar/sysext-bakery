#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Kubernetes system extension.
#

RELOAD_SERVICES_ON_MERGE="true"

# We overwrite this library function and return a list of all latest patch levels
# of all supported release branches.
function list_latest_release() {
  curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
       --retry-max-time 60 --connect-timeout 20 \
       https://raw.githubusercontent.com/kubernetes/website/main/data/releases/schedule.yaml \
       | yq -r '.schedules[] | .previousPatches[0] // (.release = .release + ".0") | .release' \
       | sed 's/^/v/'
}
# --

function list_available_versions() {
  curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
       --retry-max-time 60 --connect-timeout 20 \
       https://raw.githubusercontent.com/kubernetes/website/main/data/releases/schedule.yaml \
       | yq -r '.schedules[] | .previousPatches[] // (.release = .release + ".0") | .release' \
       | sed 's/^/v/'
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

  if [[ -z ${cni_version} ]] ; then
    cni_version="$(curl_api_wrapper https://api.github.com/repos/containernetworking/plugins/releases/latest \
                   | jq -r .tag_name)"
  fi

  announce "Using CNI version '${version}'"

  mkdir -p "${sysextroot}/usr/bin"

  curl --parallel --fail --silent --show-error --location \
    --output "${sysextroot}/usr/bin/kubectl" "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubectl" \
    --output "${sysextroot}/usr/bin/kubeadm" "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubeadm" \
    --output "${sysextroot}/usr/bin/kubelet" "https://dl.k8s.io/${version}/bin/linux/${rel_arch}/kubelet"

  curl -o cni.tgz \
       -fsSL "https://github.com/containernetworking/plugins/releases/download/${cni_version}/cni-plugins-linux-${rel_arch}-${cni_version}.tgz"

  chmod +x "${sysextroot}/usr/bin/"*

  mkdir -p "${sysextroot}/usr/local/bin/cni"
  tar --force-local -xf "cni.tgz" -C "${sysextroot}/usr/local/bin/cni"

  mkdir -p "${sysextroot}/usr/local/share/"
  echo "${version}" > "${sysextroot}/usr/local/share/kubernetes-version"
  echo "${cni_version}" > "${sysextroot}/usr/local/share/kubernetes-cni-version"

  mkdir -p "${sysextroot}/usr/libexec/kubernetes/kubelet-plugins/volume/"
  # /var/kubernetes/... will be created at runtime by the kubelet unit.
  ln -sf "/var/kubernetes/kubelet-plugins/volume/exec" "${sysextroot}/usr/libexec/kubernetes/kubelet-plugins/volume/exec"

  # Generate 2nd sysupdate config for only patchlevel upgrades.
  local sysupdate="$(get_optional_param "sysupdate" "false" "${@}")"
  if [[ ${sysupdate} == true ]] ; then
    local majorver="$(echo "${version}" | sed 's/^\(v[0-9]\+\.[0-9]\+\).*/\1/')"
    _create_sysupdate "${extname}-${majorver}" "${extname}-${majorver}.@v-%a.raw" "${extname}" "${extname}"
    mv "${extname}-${majorver}.conf" "${rundir}"
  fi
}
# --
