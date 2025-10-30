#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# tilde sysext.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  # Add sort for consuming all curl output
  curl -sSfL https://packages.debian.org/bookworm/tilde | { sort || true ; } | grep -m1 -o "tilde_.*dsc" | cut -d _ -f 2 | cut -d - -f 1
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"
  img_arch="$(arch_transform 'aarch64' 'arm64/v8' "$img_arch")"

  local lib_arch="$(arch_transform 'amd64' 'x86_64' "$arch")"
  lib_arch="$(arch_transform 'x86-64' 'x86_64' "$lib_arch")"
  lib_arch="$(arch_transform 'arm64' 'aarch64' "$lib_arch")"

  local sysextname=tilde
  docker run --rm \
              -i \
              -v "${scriptroot}/tools/":/tools \
              -v "${sysextroot}":/install_root \
              --platform "linux/${img_arch}" \
              --pull always \
              --network host \
              docker.io/debian:bookworm-slim \
                  sh -c "apt update && apt install -y tilde patchelf && cd /install_root && /tools/flix.sh / $sysextname /usr/bin/tilde /usr/lib/${lib_arch}-linux-gnu/transcript1 /usr/lib/${lib_arch}-linux-gnu/libt3widget && OWNER=\$(stat -c '%u:%g' /install_root) && if [ \"\$OWNER\" != \"\$(id -u):\$(id -g)\" ]; then chown -R \"\$OWNER\" /install_root/$sysextname; fi"
  # We ship /usr/lib/...-linux-gnu/{transcript1,libt3widget} host folders.
  # But we assume that the host has /usr/share/terminfo around
  # otherwise we would need to add it as last argument above.
  mv "${sysextroot}"/tilde/usr "${sysextroot}"/usr
  rmdir "${sysextroot}"/tilde
}
# --
