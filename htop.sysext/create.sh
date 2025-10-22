#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# htop sysext.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  # Add sort for consuming all curl output
  curl -sSfL https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/x86_64/ | { sort || true ; } | grep -m1 -o "htop-.*apk" | cut -d - -f 2
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  docker run --rm \
              -i \
              -v "${scriptroot}/tools/":/tools \
              -v "${sysextroot}":/install_root \
              --platform "linux/${img_arch}" \
              --pull always \
              --network host \
              docker.io/alpine:latest \
                  sh -c "apk add -U htop bash coreutils grep && cd /install_root && ETCMAP=chroot /tools/flatwrap.sh / htop /usr/bin/htop"
  # Alpine has /etc/terminfo instead of /usr/terminfo,
  # so above we need to skip mapping the host /etc into the flatwrap env
  mv "${sysextroot}"/htop/usr "${sysextroot}"/usr
  rmdir "${sysextroot}"/htop
  # Workaround: The bakery.sh tmp dir cleanup fails otherwise
  chmod -R u+w "${sysextroot}" || true
}
# --
