#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Podman system extension.
#
# Ships statically linked podman binaries built by the
# mgoltzsche/podman-static project. The release tarballs bundle
# podman together with conmon, crun, runc, fuse-overlayfs,
# slirp4netns, netavark, aardvark-dns and CNI plugins so the
# sysext is self-contained.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "mgoltzsche" "podman-static"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"

  local tarball="podman-linux-${rel_arch}.tar.gz"
  curl --remote-name -fsSL \
    "https://github.com/mgoltzsche/podman-static/releases/download/${version}/${tarball}"

  tar --force-local -xf "${tarball}"

  # The release tarball extracts to ./podman-linux-<arch>/{etc,usr}.
  # Move /usr contents into the sysext root; we ignore /etc since
  # extensions must not ship /etc files.
  local extracted="podman-linux-${rel_arch}"

  mkdir -p "${sysextroot}/usr"
  cp -aR "${extracted}/usr/." "${sysextroot}/usr/"

  # /usr/sbin is a symlink to /usr/bin on Flatcar. Merge any sbin
  # contents into /usr/bin so we don't clobber the symlink.
  if [[ -d "${sysextroot}/usr/sbin" ]] ; then
    cp -aR "${sysextroot}/usr/sbin/." "${sysextroot}/usr/bin/"
    rm -rf "${sysextroot}/usr/sbin"
  fi

  # The release tarball ships binaries under /usr/local. Flatcar
  # mounts /usr read-only and conventionally uses /usr/bin and
  # /usr/libexec, so flatten the /usr/local tree into /usr.
  if [[ -d "${sysextroot}/usr/local" ]] ; then
    cp -aR "${sysextroot}/usr/local/." "${sysextroot}/usr/"
    rm -rf "${sysextroot}/usr/local"
  fi
}
# --
