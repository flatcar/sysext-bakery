#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# The QEMU sysext.
#
# QEMU has no upstream static/portable release, so this extension bundles the
# qemu-system-x86_64 binary together with its shared-library closure (including
# glibc + the dynamic loader) and firmware, extracted from a Debian container.
# tools/flix.sh resolves the closure and patchelf's the binary onto a private
# loader/rpath, isolating it from the host's libraries (same approach as
# tilde.sysext). Debian packages QEMU, so the version parameter selects the
# Debian suite (stable/testing) that ships it. Only x86-64 is supported for now.

RELOAD_SERVICES_ON_MERGE="false"

DEBIAN_QEMU_API="https://sources.debian.org/api/src/qemu/"

# Print the x.y.z versions Debian stable/testing ship, newest first, from a
# Debian sources API response passed on stdin.
function _qemu_debian_versions() {
  jq -r '.versions[]? | select((.suites // []) | any(. == "stable" or . == "testing")) | .version' \
    | sed -nE 's/^[0-9]+:([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' \
    | sort -Vru
}
# --

function list_available_versions() {
  # Fail hard rather than emit a partial/empty list if the query fails.
  local api_json
  api_json="$(curl -fsSL "${DEBIAN_QEMU_API}")" || {
    echo "ERROR: failed to query the Debian sources API (${DEBIAN_QEMU_API})." >&2
    return 1
  }
  echo "${api_json}" | _qemu_debian_versions
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

  # Fetch the Debian sources API ONCE and fail hard if it can't be retrieved or
  # parsed. A transient failure must not silently change which suite (and thus
  # which QEMU version) we build against.
  local api_json
  api_json="$(curl -fsSL "${DEBIAN_QEMU_API}")" || {
    echo "ERROR: failed to query the Debian sources API (${DEBIAN_QEMU_API})." >&2
    return 1
  }
  echo "${api_json}" | jq -e '.versions' >/dev/null 2>&1 || {
    echo "ERROR: unexpected response from the Debian sources API." >&2
    return 1
  }

  # 'latest' resolves to the newest version Debian currently ships, so the suite
  # selection and version check below have a concrete target.
  if [[ "${version}" == "latest" ]]; then
    version="$(echo "${api_json}" | _qemu_debian_versions | head -1)"
    if [[ -z "${version}" ]]; then
      echo "ERROR: could not determine the latest qemu version from Debian." >&2
      return 1
    fi
  fi

  # Pick the suite that ships the requested version: prefer stable, else
  # testing, else fail. Never fall back blindly.
  local suite="" s
  for s in stable testing; do
    if echo "${api_json}" | jq -e --arg v "${version}" --arg s "${s}" '
        .versions[]?
        | select((.suites // []) | index($s))
        | select(.version | test("^[0-9]+:" + ($v | gsub("\\.";"\\.")) + "([-+~]|$)"))
      ' >/dev/null; then
      suite="${s}"
      break
    fi
  done
  if [[ -z "${suite}" ]]; then
    echo "ERROR: qemu ${version} is not available in Debian stable or testing." >&2
    return 1
  fi

  # Build the sysext inside a Debian container of the chosen suite: install QEMU,
  # verify it actually matches the requested version (a moved suite must not
  # silently produce a different build), then hand the binary + firmware to
  # tools/flix.sh, which resolves the library closure and patchelf's the binary
  # onto a private loader/rpath. No -L wrapper is needed: QEMU finds firmware in
  # its compiled-in data dir (/usr/share/qemu), which we ship.
  docker run --rm -i \
    -v "${scriptroot}/tools/":/tools \
    -v "${sysextroot}":/install_root \
    --platform linux/amd64 \
    --pull always \
    --network host \
    -e WANT_VERSION="${version}" \
    "docker.io/debian:${suite}-slim" bash -euc '
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq --no-install-recommends \
        qemu-system-x86 qemu-system-data seabios ipxe-qemu ovmf patchelf >/dev/null

      got="$(qemu-system-x86_64 --version \
        | sed -nE "s/.*version ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p" | head -1)"
      if [ "${got}" != "${WANT_VERSION}" ]; then
        echo "ERROR: requested qemu ${WANT_VERSION} but Debian installs ${got}." >&2
        exit 1
      fi

      # Bundle the binary plus whichever firmware data dirs the suite ships.
      paths="/usr/bin/qemu-system-x86_64"
      for d in qemu seabios ipxe ovmf OVMF; do
        [ -d "/usr/share/${d}" ] && paths="${paths} /usr/share/${d}"
      done

      cd /install_root
      /tools/flix.sh / qemu ${paths}

      owner="$(stat -c "%u:%g" /install_root)"
      if [ "${owner}" != "$(id -u):$(id -g)" ]; then
        chown -R "${owner}" /install_root/qemu
      fi
    '

  mv "${sysextroot}/qemu/usr" "${sysextroot}/usr"
  rmdir "${sysextroot}/qemu"
}
# --
