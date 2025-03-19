#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# CRI-O system extension.
#

RELOAD_SERVICES_ON_MERGE="true"

# --

function list_available_versions() {
  list_github_releases "cri-o" "cri-o"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # For compatibility with existing automation.
  [[ "${version}" == v* ]] || version="v${version}"

  # releases arch identifiers differ from what extension images use
  local rel_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"

  curl -o "cri-o.${rel_arch}.${version}.tar.gz" \
       -fsSL "https://storage.googleapis.com/cri-o/artifacts/cri-o.${rel_arch}.${version}.tar.gz"
  tar --force-local -xf "cri-o.${rel_arch}.${version}.tar.gz"

  cd cri-o
  # Hack alert: removes sed replacements from install script to keep the default location (/usr) in the base config file
  sed -i '/^sed -i.*DESTDIR/d' install 

  DESTDIR="${sysextroot}" \
    PREFIX=/usr \
    ETCDIR=$PREFIX/share/crio/etc \
    OCIDIR=$PREFIX/share/oci-umount/oci-umount.d \
    CNIDIR=$PREFIX/share/crio/cni/etc/net.d/ \
    OPT_CNI_BIN_DIR=$PREFIX/share/crio/cni/bin/  \
    BASHINSTALLDIR=./ FISHINSTALLDIR=./ ZSHINSTALLDIR=./ MANDIR=./ \
    ./install 
}
# --
