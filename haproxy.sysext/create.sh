#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# HAProxy system extension.
#
# Builds a statically linked haproxy from upstream source against the
# Alpine musl toolchain and ships it under /usr/bin/haproxy.
#

RELOAD_SERVICES_ON_MERGE="true"

# Stable haproxy releases use plain "X.Y.Z" tags.
EXTENSION_VERSION_MATCH_PATTERN='[0-9.]+'

# HAProxy publishes one /download/<X.Y>/src/ directory per branch with a
# releases.json index. Iterate every branch and collect stable releases
# (skip "X.Y-devN", "X.Y-dev0", etc.) across all of them.
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
    curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
      --retry-max-time 60 --connect-timeout 20 \
      "https://www.haproxy.org/download/${branch}/src/releases.json" \
      | jq -r '.releases | keys[]' 2>/dev/null \
      | grep -vE -- '-(dev|rc)' || true
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
    ${image} \
        /install_root/build.sh "${version}" "$user_group"

  cp -aR usr "${sysextroot}/"
}
# --
