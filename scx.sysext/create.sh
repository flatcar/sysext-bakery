#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# sched-ext/scx system extension.
# Provides sched_ext schedulers for Linux.

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  list_github_releases "sched-ext" "scx"
}
# --

function populate_sysext_root_options() {
  echo "  --scheduler <name>  : Default scheduler to use (default: scx_bpfland)."
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local scheduler="$(get_optional_param "scheduler" "scx_bpfland" "${@}")"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  local image="docker.io/alpine:latest"

  announce "Building scx $version for $arch"

  local user_group="$(id -u):$(id -g)"

  cp "${scriptroot}/scx.sysext/build.sh" .
  docker run --rm \
    -i \
    -v "$(pwd)":/install_root \
    --platform "linux/${img_arch}" \
    --pull always \
    ${image} \
      /install_root/build.sh "${version}" "$user_group"

  cp -aR usr "${sysextroot}"/

  # Update default scheduler in config if specified
  if [[ "${scheduler}" != "scx_bpfland" ]]; then
    sed -i "s/SCX_SCHEDULER=scx_bpfland/SCX_SCHEDULER=${scheduler}/" \
      "${sysextroot}/usr/share/scx/scx"
  fi
}
# --
