#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# HAProxy Data Plane API system extension.
#
# Ships the upstream "dataplaneapi" Go binary from the linux release
# tarball.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "haproxytech" "dataplaneapi"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # Upstream artefact names use "x86_64" / "arm64".
  local rel_arch="$(arch_transform 'x86-64' 'x86_64' "$arch")"

  # Tarballs are named with the version sans leading "v".
  local rel_version="${version#v}"

  local tarball="dataplaneapi_${rel_version}_linux_${rel_arch}.tar.gz"
  local base_url="https://github.com/haproxytech/dataplaneapi/releases/download/${version}"

  curl --parallel --fail --silent --show-error --location \
    --remote-name "${base_url}/${tarball}" \
    --remote-name "${base_url}/checksums.txt"

  local expected
  expected="$(awk -v t="${tarball}" \
    '$2 == t || $2 == "*"t {print $1; exit}' \
    checksums.txt)"
  if [[ -z "${expected}" ]] ; then
    echo "ERROR: ${tarball} not listed in upstream checksums file." >&2
    return 1
  fi
  echo "${expected}  ${tarball}" | sha256sum -c -

  mkdir -p "${sysextroot}/usr/bin" extract
  tar --force-local -xf "${tarball}" -C extract
  local binary
  binary="$(find extract -type f -name dataplaneapi -print -quit)"
  if [[ -z "${binary}" ]] ; then
    echo "ERROR: dataplaneapi binary not found in ${tarball}." >&2
    return 1
  fi
  install -m 0755 "${binary}" "${sysextroot}/usr/bin/dataplaneapi"
}
# --
