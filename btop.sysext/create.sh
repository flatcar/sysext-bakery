#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# btop sysext.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  # Add sort for consuming all curl output
  # (When copying this, you might need to switch to 'main' from 'community')
  curl -sSfL https://dl-cdn.alpinelinux.org/alpine/latest-stable/community/x86_64/ | { sort || true ; } | grep -m1 -o "btop-.*apk" | cut -d - -f 2
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  local sysextname=btop
  docker run --rm \
              -i \
              -v "${scriptroot}/tools/":/tools \
              -v "${sysextroot}":/install_root \
              --platform "linux/${img_arch}" \
              --pull always \
              --network host \
              docker.io/alpine:latest \
                  sh -c "apk add -U btop bash coreutils grep && cd /install_root && ETCMAP=chroot /tools/flatwrap.sh / $sysextname /usr/bin/btop && OWNER=\$(stat -c '%u:%g' /install_root) && if [ \"\$OWNER\" != \"\$(id -u):\$(id -g)\" ]; then chown -R \"\$OWNER\" /install_root/$sysextname; fi"
  # Alpine has /etc/terminfo instead of /usr/terminfo,
  # so above we need to skip mapping the host /etc into the flatwrap env
  mv "${sysextroot}"/btop/usr "${sysextroot}"/usr
  rmdir "${sysextroot}"/btop
  # Workaround: The bakery.sh tmp dir cleanup fails otherwise
  chmod -R u+w "${sysextroot}" || true
}
# --
