#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Kata Containers system extension.
#
# Ships the upstream "kata-static" release tarball, which bundles
# the kata runtime, agent, shim, guest kernel, initrd and a hypervisor
# (QEMU and/or Cloud Hypervisor).
#
# The tarball installs under /opt/kata, but this sysext relocates it to
# /usr/lib/kata and recreates /opt/kata as a symlink via tmpfiles.d. The reason
# is that systemd-sysext merges a hierarchy by mounting a READ-ONLY overlay over
# it, and it merges /opt as well as /usr. So an extension that ships anything
# under /opt makes the host's entire /opt read-only for as long as the extension
# is merged -- which breaks any unrelated software that writes there, and is
# surprising because /opt is writable on a stock Flatcar. Keeping the image
# clear of /opt leaves the host's /opt writable, and the tmpfiles symlink
# preserves every /opt/kata path kata itself still refers to.
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

  # Kata doesn't publish a separate checksum file, but recent releases
  # carry a SHA-256 digest in the GitHub release asset metadata. Fetch
  # and verify it; warn (don't fail) on older releases that pre-date the
  # digest field.
  local digest
  digest="$(curl_api_wrapper \
    "https://api.github.com/repos/kata-containers/kata-containers/releases/tags/${rel_version}" \
    | jq -r --arg n "${tarball}" '.assets[] | select(.name == $n) | .digest // empty' \
    | sed -n 's|^sha256:||p')"
  if [[ -n "${digest}" ]] ; then
    echo "${digest}  ${tarball}" | sha256sum -c -
  else
    echo "WARNING: upstream did not publish a SHA-256 digest for ${tarball}; skipping integrity check." >&2
  fi

  # The tarball expands to ./opt/kata/{bin,libexec,share,...}.
  tar --force-local -xf "${tarball}"

  # Relocate to /usr/lib/kata: shipping /opt would make the host's /opt a
  # read-only overlay. files/usr/lib/tmpfiles.d/10-kata-containers-opt.conf
  # restores /opt/kata as a symlink to this, so kata's compiled-in default
  # config path and the absolute paths inside the shipped configuration.toml
  # files keep resolving.
  mkdir -p "${sysextroot}/usr/lib"
  cp -aR opt/kata "${sysextroot}/usr/lib/kata"

  # Expose the user-facing binaries via /usr/bin so they're on $PATH
  # after the sysext is merged. Use relative symlinks so they continue
  # to work regardless of where the sysext is mounted.
  mkdir -p "${sysextroot}/usr/bin"
  local bin
  for bin in kata-runtime containerd-shim-kata-v2 ; do
    if [[ ! -e "${sysextroot}/usr/lib/kata/bin/${bin}" ]] ; then
      echo "ERROR: expected binary ${bin} missing from kata-static ${rel_version}." >&2
      return 1
    fi
    ln -sf "../lib/kata/bin/${bin}" "${sysextroot}/usr/bin/${bin}"
  done
  if [[ -e "${sysextroot}/usr/lib/kata/bin/kata-collect-data.sh" ]] ; then
    ln -sf "../lib/kata/bin/kata-collect-data.sh" \
      "${sysextroot}/usr/bin/kata-collect-data.sh"
  fi
}
# --
