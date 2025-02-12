#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Wasmcloud system extension.
#
RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "wasmcloud" "wasmcloud" | grep -E '^v[0-9.]+$'
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "x86_64" "$arch")"
  local rel_arch="$(arch_transform "arm64" "aarch64" "$rel_arch")"
  local go_arch="$(arch_transform "x86-64" "amd64" "$arch")"

  local nats="$(get_optional_param "nats" "latest" "${@}")"
  if [[ $nats == latest ]] ; then
    nats="$(curl -fsSL https://api.github.com/repos/nats-io/nats-server/releases/latest | jq -r .tag_name)"
  fi

  echo "Using NATS server version '$nats'"
  curl --parallel --fail --silent --show-error --location \
        --remote-name "https://github.com/wasmcloud/wasmcloud/releases/download/${version}/wasmcloud-${rel_arch}-unknown-linux-musl" \
        --remote-name "https://github.com/nats-io/nats-server/releases/download/${nats}/nats-server-${nats}-linux-${go_arch}.tar.gz"

  tar --force-local -xf "nats-server-${nats}-linux-${go_arch}.tar.gz"

  mkdir -p "${sysextroot}/usr/bin"
  cp -a "wasmcloud-${rel_arch}-unknown-linux-musl" "${sysextroot}/usr/bin/wasmcloud"
  cp -a "nats-server-${nats}-linux-${go_arch}/nats-server" "${sysextroot}/usr/bin/"
}
# --

function populate_sysext_root_options() {
  echo "  --nats-version <version> : Include NATS server version <version> instead of latest."
  echo "     For a list of versions, see https://github.com/nats-io/nats-server/releases"
}
# --

