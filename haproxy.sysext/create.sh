#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# HAProxy system extension.
#
# Builds a static musl-linked haproxy from upstream source inside an
# ephemeral alpine container, so the sysext has no runtime library
# dependencies on the host.
#

RELOAD_SERVICES_ON_MERGE="true"

# Stable haproxy releases use plain "X.Y.Z" tags.
EXTENSION_VERSION_MATCH_PATTERN='[0-9.]+'

# HAProxy publishes one /download/<X.Y>/src/ directory per branch with a
# releases.json index. Iterate every branch and collect stable releases
# (skip "X.Y-devN", "X.Y-dev0", etc.) across all of them.
#
# Branches prior to 3.0 are excluded: they expect older library headers
# (most notably OpenSSL) that Alpine no longer provides, so those builds
# fail or produce noisy output. As a side benefit this skips 1.0, whose
# releases.json is almost empty and would make jq error out.
function list_available_versions() {
  local listing branches branch
  listing="$(curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
    --retry-max-time 60 --connect-timeout 20 \
    "https://www.haproxy.org/download/")"

  branches="$(echo "${listing}" \
    | grep -oE 'href="[0-9]+\.[0-9]+/"' \
    | sed -E 's|href="||;s|/"||' \
    | sort -uV)"

  for branch in ${branches} ; do
    if semver_lower "${branch}" "3.0" ; then
      continue
    fi
    curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
      --retry-max-time 60 --connect-timeout 20 \
      "https://www.haproxy.org/download/${branch}/src/releases.json" \
      | jq -r '.releases | keys[]' \
      | { grep -vE -- '-(dev|rc)' || true; }
  done | sort -Vr
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch
  img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  local image="docker.io/alpine:3.21"

  announce "Building haproxy $version for $arch"

  local user_group="$(id -u):$(id -g)"

  cp "${scriptroot}/haproxy.sysext/build.sh" .
  docker run --rm \
    -i \
    -v "$(pwd)":/install_root \
    --platform "linux/${img_arch}" \
    --pull always \
    --network host \
    "${image}" \
        /install_root/build.sh "${version}" "$user_group"

  # build.sh installs to /install_root/usr; merge that on top of the
  # static files already staged in ${sysextroot}/usr. Use the /. trick
  # so cp merges into an existing directory instead of nesting.
  mkdir -p "${sysextroot}/usr"
  cp -a usr/. "${sysextroot}/usr/"
}
# --
