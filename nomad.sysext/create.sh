#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  curl -fsSL --retry-delay 1 --retry 60 \
    --retry-connrefused --retry-max-time 60 --connect-timeout 20 \
    https://api.releases.hashicorp.com/v1/releases/nomad \
  | jq -r '.[] | select(has("version"))
               | .version
               | select(type == "string")
               | select(test("^[0-9.]+$"))
               | capture("(?<v>[[:digit:].]+)").v' \
  | sort -Vr
}
# --

function populate_sysext_root_options() {
  echo "  --with-cni <version> : Also ship CNI plugin <version> in the sysext, and"
  echo "                  point Nomad's cni_path at it. Pass 'latest' for the newest"
  echo "                  release. Nomad needs these for its bridge network mode."
  echo "                  For a list of CNI plugin versions, please refer to"
  echo "                  https://github.com/containernetworking/plugins/releases"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local cni
  cni="$(get_optional_param "with-cni" "" "$@")"

  local rel_arch
  rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  curl -fsSLZO --retry-delay 1 --retry 60 \
    --retry-connrefused --retry-max-time 60 --connect-timeout 20 \
    "https://releases.hashicorp.com/nomad/${version}/nomad_${version}_linux_${rel_arch}.zip"
  # Unzip the binary
  mkdir -p "${sysextroot}/usr/bin"
  unzip -q "nomad_${version}_linux_${rel_arch}.zip"
  install -m 0755 nomad "${sysextroot}/usr/bin"

  if [[ -n "${cni}" ]] ; then
    install_cni_plugins "${sysextroot}" "${arch}" "${cni}" "usr/libexec/cni"
    announce "Bundled CNI plugins ${CNI_PLUGINS_VERSION}"
  else
    # Without the plugins the cni_path drop-in would point Nomad at an empty
    # directory, so drop it and leave the stock config alone.
    rm -f "${sysextroot}/usr/share/nomad/cni.hcl" \
          "${sysextroot}/usr/lib/tmpfiles.d/11-nomad-cni.conf"
  fi
}
# --
