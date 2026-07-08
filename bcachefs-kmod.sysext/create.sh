#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# bcachefs kernel module system extension.
#
# bcachefs was removed from mainline in Linux 6.18 (September 2025) — the
# in-tree code was marked stale and replaced by an out-of-tree DKMS module
# maintained by Kent Overstreet in koverstreet/bcachefs-tools. This sysext
# builds that DKMS module against a specific Flatcar release's kernel and
# packages the resulting bcachefs.ko for merge onto a matching host.
#
# The build runs inside Flatcar's own SDK container image
# (ghcr.io/flatcar/flatcar-sdk-all:<flatcar-release>), which ships the exact
# kernel source Flatcar was built with — no need to fetch a vanilla kernel,
# reconstruct .config, or manually run modules_prepare. The DKMS harness in
# bcachefs-tools/dkms/ handles the out-of-tree build.
#
# This sysext is NOT part of the bakery's automated release matrix: a single
# build pins (bcachefs revision, Flatcar release/kernel) and the resulting
# .ko only loads on the exact matching kernel. Auto-updating via
# systemd-sysupdate would silently break on kernel bumps, so the sysext is
# not listed in release_build_versions.txt for `latest` scanning.

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  # Kernel and userspace bcachefs sources both live in bcachefs-tools now;
  # tag list here is what feeds `bakery.sh list bcachefs-kmod`.
  list_github_tags "koverstreet" "bcachefs-tools"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local flatcar_release
  flatcar_release="$(get_optional_param "flatcar-release" "stable" "$@")"

  # Resolve channel names to a specific release version; leave numeric
  # release versions untouched. The SDK container is tagged by release
  # version so we need the concrete number below.
  case "${flatcar_release}" in
    alpha|beta|stable|lts)
      flatcar_release="$(curl -fsSL --retry-delay 1 --retry 60 \
        --retry-connrefused --retry-max-time 60 --connect-timeout 20 \
        https://www.flatcar.org/releases-json/releases.json \
        | jq -r --arg ch "$flatcar_release" '
            to_entries[]
            | select(.value.channel == $ch)
            | .key
            | capture("^(?<v>[0-9]+\\.[0-9]+\\.[0-9]+)").v' \
        | sort -Vr | head -n1)"
      [ -n "${flatcar_release}" ] || {
        echo "ERROR: could not resolve channel to a Flatcar release" >&2
        exit 1
      }
      ;;
  esac

  # Flatcar's SDK container is published only for amd64. Cross-compilation
  # for arm64 targets would require driving the SDK's board-selection
  # machinery from build.sh — punting on that for now.
  if [ "${arch}" != "x86-64" ] ; then
    echo "ERROR: bcachefs-kmod currently only supports --arch x86-64;" \
         "the Flatcar SDK container is not published for other arches." >&2
    exit 1
  fi

  announce "Building bcachefs-kmod ${version} against Flatcar ${flatcar_release} for ${arch}"

  local user_group="$(id -u):$(id -g)"

  cp "${scriptroot}/bcachefs-kmod.sysext/build.sh" .

  docker run --rm -i \
    -v "$(pwd)":/install_root \
    --platform linux/amd64 \
    --pull always \
    "ghcr.io/flatcar/flatcar-sdk-all:${flatcar_release}" \
      /install_root/build.sh "${version}" "${user_group}"

  cp -aR usr "${sysextroot}"/
}
# --

function populate_sysext_root_options() {
  echo "  --flatcar-release <version|channel>"
  echo "                    Flatcar release to build the module for."
  echo "                    Accepts a release version (e.g. '4230.2.0') or a"
  echo "                    channel name ('alpha', 'beta', 'stable', 'lts');"
  echo "                    channel names resolve to that channel's current"
  echo "                    release. This value is used as the tag for the"
  echo "                    ghcr.io/flatcar/flatcar-sdk-all build container."
  echo "                    Default: 'stable'."
}
# --
