#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# The Ollama system extension.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "ollama" "ollama"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch
  rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"

  local sufx="tgz"
  if semver_equals_or_higher "${version}" "v0.14.0" ; then
    sufx="tar.zst"
  fi

  local tarball="ollama-linux-${rel_arch}.${sufx}"

  echo "This might take a while as the Ollama download is pretty sizeable (about 1.5 GB)."
  curl --parallel --fail --silent --show-error --location \
    --remote-name "https://github.com/ollama/ollama/releases/download/${version}/${tarball}" \
    --remote-name "https://github.com/ollama/ollama/releases/download/${version}/sha256sum.txt"

  grep -F "${tarball}" sha256sum.txt | sha256sum -c -

  mkdir -p "${sysextroot}/usr/local"
  tar --force-local -xf "${tarball}" -C "${sysextroot}/usr/local"
  chmod +x "${sysextroot}/usr/local/bin/ollama"
}
# --
