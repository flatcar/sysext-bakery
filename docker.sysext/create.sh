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

  local without="$(get_optional_param "without" "" "$@")"

  # The github release uses different arch identifiers
  local rel_arch="$(arch_transform 'x86-64' 'x86_64' "$arch")"
  rel_arch="$(arch_transform 'arm64' 'aarch64' "$rel_arch")"

  curl -o "docker-${version}.tgz" \
         -fsSL "https://download.docker.com/linux/static/stable/${rel_arch}/docker-${version}.tgz"
  tar --force-local -xf "docker-${version}.tgz"

  mkdir -p "${sysextroot}"/usr/bin
  cp -R docker/* "${sysextroot}"/usr/bin/

  announce "Removing containerd / runc from sysext as requested (shipping docker only)"

  rm "${sysextroot}/usr/bin/containerd" \
      "${sysextroot}/usr/bin/containerd-shim-runc-v2" \
      "${sysextroot}/usr/bin/ctr" \
      "${sysextroot}/usr/bin/runc" \
      "${sysextroot}/usr/lib/systemd/system/containerd.service" \
      "${sysextroot}/usr/lib/systemd/system/multi-user.target.d/10-containerd-service.conf" \
      "${sysextroot}/usr/share/containerd/config.toml" \
      "${sysextroot}/usr/share/containerd/config-cgroups.toml"

    rmdir "${sysextroot}/usr/share/containerd" \
          "${sysextroot}/usr/lib/systemd/system/multi-user.target.d/"

  # Always build the containerd-docker sysext
  announce "Building containerd-docker sysext based on containerd from Docker"
  
  # Create a temporary directory for the containerd-docker sysext
  local containerd_docker_root="$(mktemp -d)"
  trap "rm -rf '${containerd_docker_root}'" EXIT
  
  mkdir -p "${containerd_docker_root}/usr/bin"
  
  # Copy only containerd and runc components
  cp docker/containerd \
     docker/containerd-shim-runc-v2 \
     docker/ctr \
     docker/runc \
     "${containerd_docker_root}/usr/bin/"
  
  # Copy the static files from our containerd-docker.sysext/files directory
  if [[ -d "${scriptroot}/containerd-docker.sysext/files" ]]; then
    cp -R "${scriptroot}/containerd-docker.sysext/files/"* "${containerd_docker_root}/"
  fi
  
  # Generate the containerd-docker sysext
  announce "Generating containerd-docker sysext file system image"
  generate_sysext "${containerd_docker_root}" "$arch" "${@}" --force-reload true --name "containerd-docker"
}
# --
