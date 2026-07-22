#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# The Docker sysext.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  # Hack alert: we're extracting the list of available versions
  #  from the release server's X86-64 release tarballs' HTML file listing.
  # This should be improved with a better source.

  curl -fsSL https://download.docker.com/linux/static/stable/x86_64/ \
      | sed -n 's/.*docker-\([0-9.]\+\).tgz.*/\1/p' \
      | sort -Vr
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # The github release uses different arch identifiers
  local rel_arch="$(arch_transform 'x86-64' 'x86_64' "$arch")"
  rel_arch="$(arch_transform 'arm64' 'aarch64' "$rel_arch")"

  curl -o "docker-${version}.tgz" \
         -fsSL "https://download.docker.com/linux/static/stable/${rel_arch}/docker-${version}.tgz"
  tar --force-local -xf "docker-${version}.tgz"

  mkdir -p "${sysextroot}"/usr/bin
  cp -R docker/* "${sysextroot}"/usr/bin/

  announce "Removing containerd / runc from sysext as it has its own sysext"

  rm "${sysextroot}/usr/bin/containerd" \
      "${sysextroot}/usr/bin/containerd-shim-runc-v2" \
      "${sysextroot}/usr/bin/ctr" \
      "${sysextroot}/usr/bin/runc"
}
# --
