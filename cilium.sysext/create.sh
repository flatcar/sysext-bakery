#!/usr/bin/env bash

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "cilium" "cilium-cli"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  arch="$(arch_transform 'x86-64' 'amd64' "${arch}")"

  tarball="cilium-linux-${arch}.tar.gz"
  shasum="${tarball}.sha256sum"

  tarball_url="https://github.com/cilium/cilium-cli/releases/download/${version}/${tarball}"
  shasum_url="https://github.com/cilium/cilium-cli/releases/download/${version}/${shasum}"
  echo "Downloading ${tarball_url}"

  curl --parallel --fail --silent --show-error --location \
    --output "${tarball}" "${tarball_url}" \
    --output "${shasum}" "${shasum_url}"

  sha256sum -c "${shasum}"

  mkdir -p "${sysextroot}/usr/local/bin"
  tar --force-local -xf "${tarball}" -C "${sysextroot}/usr/local/bin"
  chmod +x "${sysextroot}/usr/local/bin/cilium"
}
# --
