#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# The QEMU sysext.
#
# QEMU has no upstream static/portable release, so this extension bundles the
# qemu-system-x86_64 binary together with its full shared-library closure
# (including glibc + the dynamic loader) and firmware, extracted from a Debian
# container. A /usr/bin wrapper runs the binary through the bundled loader so it
# is isolated from the host's libraries — making it portable onto Flatcar.
#
# The version parameter is the QEMU version; it selects the Debian suite that
# ships it (stable/testing). Only x86-64 is supported for now.

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  # QEMU versions available from Debian stable / testing.
  curl -fsSL "https://sources.debian.org/api/src/qemu/" 2>/dev/null \
    | jq -r '.versions[]? | select((.suites // []) | any(. == "stable" or . == "testing"))
             | .version' \
    | sed -nE 's/^[0-9]+:([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' \
    | sort -Vru
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  if [[ "${arch}" != "x86-64" ]]; then
    echo "ERROR: the qemu sysext currently supports only x86-64." >&2
    return 1
  fi

  # Pick the Debian suite whose qemu matches the requested version.
  local suite="stable"
  if ! curl -fsSL "https://sources.debian.org/api/src/qemu/" 2>/dev/null \
       | jq -e --arg v "${version}" '.versions[]? | select((.suites // []) | index("stable"))
                                     | select(.version | test("^[0-9]+:" + ($v | gsub("\\.";"\\.")) ))' >/dev/null; then
    suite="testing"
  fi

  # Extract qemu + its runtime closure + firmware into the sysext root, and
  # write the loader wrapper. Runs in a Debian container of the chosen suite.
  docker run --rm -v "${sysextroot}:/out" "debian:${suite}-slim" bash -euc '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends \
      qemu-system-x86 qemu-system-data seabios ipxe-qemu ovmf >/dev/null

    bundle=/out/usr/lib/qemu-bundle
    mkdir -p "$bundle" /out/usr/bin /out/usr/share

    bin=/usr/bin/qemu-system-x86_64
    cp -aL "$bin" "$bundle/qemu-system-x86_64"

    copy_libs() {
      local f="$1" lib dest
      ldd "$f" 2>/dev/null | sed -nE "s/.*=> (\/[^ ]+).*/\1/p; s/^\s*(\/lib[^ ]*ld-[^ ]+).*/\1/p" \
        | sort -u | while read -r lib; do
          [ -e "$lib" ] || continue
          dest="$bundle/$(basename "$lib")"
          [ -e "$dest" ] && continue
          cp -aL "$lib" "$dest"
          copy_libs "$lib"
        done
    }
    copy_libs "$bin"
    [ -d /usr/lib/x86_64-linux-gnu/qemu ] && cp -aL /usr/lib/x86_64-linux-gnu/qemu "$bundle/modules" || true

    for d in qemu seabios ipxe ovmf OVMF; do
      [ -d "/usr/share/$d" ] && cp -aL "/usr/share/$d" /out/usr/share/ || true
    done

    loader="$(basename "$(ls "$bundle"/ld-linux* | head -1)")"
    cat > /out/usr/bin/qemu-system-x86_64 <<EOF
#!/bin/sh
b=/usr/lib/qemu-bundle
exec "\$b/$loader" --library-path "\$b:\$b/modules" \
  "\$b/qemu-system-x86_64" -L /usr/share/qemu "\$@"
EOF
    chmod +x /out/usr/bin/qemu-system-x86_64
  '
}
# --
