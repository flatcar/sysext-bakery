#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Test script for the coredns sysext.
#
# Usage: ./coredns.sysext/test.sh [<image.raw>]
#
# Checks a built squashfs image. Defaults to "coredns.raw" in the current
# directory. "coredns -version" only runs when the image arch matches the host.

set -euo pipefail

image="${1:-coredns.raw}"

if [[ ! -f ${image} ]] ; then
  echo "ERROR: no such image '${image}'. Build one with './bakery.sh create coredns <version>'."
  exit 1
fi

failures=0

function check() {
  local what="$1"
  shift

  if "${@}" ; then
    echo "PASS: ${what}"
  else
    echo "FAIL: ${what}"
    : $((failures++))
  fi
}
# --

workdir="$(mktemp -d)"
trap "rm -rf '${workdir}'" EXIT

unsquashfs -no-progress -force -dest "${workdir}/root" "${image}" >/dev/null
root="${workdir}/root"

# The image must merge into /usr only. A sysext merges both /usr and /opt, and
# a hierarchy becomes a read-only overlay as soon as any merged image ships it.
# Shipping /opt here would hide files consumers place there at install time.
function only_usr() {
  local stray
  stray="$(find "${root}" -mindepth 1 -maxdepth 1 -not -name usr -printf '%f\n')"

  if [[ -n ${stray} ]] ; then
    echo "  unexpected top level entries: ${stray//$'\n'/ }"
    return 1
  fi
}
# --

check "image contains no path outside /usr" only_usr
check "/usr/bin/coredns is a regular file" test -f "${root}/usr/bin/coredns"
check "/usr/bin/coredns is executable" test -x "${root}/usr/bin/coredns"
check "ships a coredns.service unit" \
  test -f "${root}/usr/lib/systemd/system/coredns.service"
check "ships a sysusers.d entry for the coredns user" \
  test -f "${root}/usr/lib/sysusers.d/coredns.conf"
check "ships no Corefile CoreDNS would read by default" \
  test ! -e "${root}/usr/share/coredns/Corefile"

# Read e_machine from the ELF header to learn what the binary was built for.
# 0x3e is x86-64, 0xb7 is aarch64.
function elf_machine() {
  od -An -tx1 -j18 -N2 "$1" | tr -d ' \n'
}
# --

host_machine=""
case "$(uname -m)" in
  x86_64)  host_machine="3e00";;
  aarch64) host_machine="b700";;
esac

# The binary is static, so it runs straight out of the extracted tree.
if [[ -n ${host_machine} ]] \
   && [[ "$(elf_machine "${root}/usr/bin/coredns")" == "${host_machine}" ]] ; then
  check "coredns -version runs" "${root}/usr/bin/coredns" -version
else
  echo "SKIP: coredns -version (image architecture differs from the host)"
fi

echo
if [[ ${failures} -gt 0 ]] ; then
  echo "${failures} check(s) failed."
  exit 1
fi

echo "All checks passed."
