#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# The containerd-docker sysext.
# Built from the containerd components of the docker sysext.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  # Use the same versions list as docker sysext
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
  
  # Copy only containerd and runc components
  cp docker/containerd \
     docker/containerd-shim-runc-v2 \
     docker/ctr \
     docker/runc \
     "${sysextroot}"/usr/bin/
  
  # Create required directories for systemd files
  mkdir -p "${sysextroot}/usr/lib/systemd/system/multi-user.target.d/"
  mkdir -p "${sysextroot}/usr/share/containerd"
}
# -- 