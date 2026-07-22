#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Prometheus node_exporter sysext.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "prometheus" "node_exporter"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  local tarball="node_exporter-${version#v}.linux-${rel_arch}.tar.gz"
  local baseurl="https://github.com/prometheus/node_exporter/releases/download/${version}"

  curl --parallel --fail --silent --show-error --location \
    --remote-name "${baseurl}/${tarball}" \
    --remote-name "${baseurl}/sha256sums.txt"

  # Verify the tarball against its published checksum. Pick out the specific
  # entry and fail if it is missing: 'sha256sum --ignore-missing' would exit 0
  # when nothing matches, verifying nothing at all.
  local expected
  # Match the filename with or without the coreutils binary marker ('*').
  expected="$(awk -v f="${tarball}" '$2 == f || $2 == "*" f' sha256sums.txt)"
  if [[ -z "${expected}" ]] ; then
    echo "ERROR: no checksum entry for ${tarball} in sha256sums.txt" >&2
    return 1
  fi
  echo "${expected}" | sha256sum --check --strict -

  tar --force-local --strip-components=1 -xzf "${tarball}"

  mkdir -p "${sysextroot}/usr/bin"
  install -m 0755 node_exporter "${sysextroot}/usr/bin/"
}
# --
