#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Kata Containers system extension.
#
# Ships the upstream "kata-static" release tarball, which bundles
# the kata runtime, agent, shim, guest kernel, initrd and a hypervisor
# (QEMU and/or Cloud Hypervisor) under /opt/kata.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "kata-containers" "kata-containers"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # Upstream artefact names use "amd64" / "arm64".
  local rel_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"

  # Strip a leading "v" if present: kata tags are "3.21.0" not "v3.21.0".
  local rel_version="${version#v}"

  # Upstream switched the release tarball compression from xz to zstd
  # starting with 3.21.0.
  local sufx="tar.xz"
  if semver_equals_or_higher "${rel_version}" "3.21.0" ; then
    sufx="tar.zst"
  fi

  local tarball="kata-static-${rel_version}-${rel_arch}.${sufx}"
  curl --remote-name -fsSL \
    "https://github.com/kata-containers/kata-containers/releases/download/${rel_version}/${tarball}"

  # The tarball expands to ./opt/kata/{bin,libexec,share,...}.
  tar --force-local -xf "${tarball}"

  mkdir -p "${sysextroot}/opt"
  cp -aR opt/kata "${sysextroot}/opt/"

  # Expose the user-facing binaries via /usr/bin so they're on $PATH
  # after the sysext is merged. Use relative symlinks so they continue
  # to work regardless of where the sysext is mounted.
  mkdir -p "${sysextroot}/usr/bin"
  local bin
  for bin in kata-runtime kata-collect-data.sh containerd-shim-kata-v2 ; do
    if [[ -e "${sysextroot}/opt/kata/bin/${bin}" ]] ; then
      ln -sf "../../opt/kata/bin/${bin}" "${sysextroot}/usr/bin/${bin}"
    fi
  done
}
# --
