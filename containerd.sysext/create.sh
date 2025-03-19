#!/usr/bin/env bash

# Containerd sysext generation script.

RELOAD_SERVICES_ON_MERGE="true"

# --

function list_available_versions() {
  # filter "api" releases, remove leading "v" since we don't use it in the sysext file name
  list_github_releases "containerd" "containerd" \
    | grep -vE '^api/' \
    | sed 's/^v//'
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # The github release uses different arch identifiers
  local rel_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"

  echo "Downloading containerd version ${version} for ${arch}"

  curl --remote-name -fsSL \
      "https://github.com/containerd/containerd/releases/download/v${version}/containerd-static-${version}-linux-${rel_arch}.tar.gz{,.sha256sum}"
  sha256sum --check "containerd-static-${version}-linux-${rel_arch}.tar.gz.sha256sum"
  tar --force-local -xf "containerd-static-${version}-linux-${rel_arch}.tar.gz"

  local runc_version="$(curl -fsSL "https://raw.githubusercontent.com/containerd/containerd/refs/tags/v${version}/script/setup/runc-version")"
  echo "Downloading associated runc version: ${runc_version}"
  curl --remote-name -fsSL "https://github.com/opencontainers/runc/releases/download/${runc_version}/runc.{${rel_arch},sha256sum}"
  sha256sum --ignore-missing -c runc.sha256sum

  mkdir -p "${sysextroot}/usr/bin"
  cp -aR --no-dereference bin/* "${sysextroot}/usr/bin/"
  cp -a "runc.${rel_arch}" "${sysextroot}/usr/bin/runc"

  chmod a+x "${sysextroot}/usr/bin/runc"
}
