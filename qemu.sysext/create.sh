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

# Resolve a Debian suite alias (stable/testing) to its codename from the archive
# Release file, e.g. stable -> trixie. The sources API tags versions by codename
# only, so we need this mapping. Fails if the lookup can't be made.
function _debian_codename() {
  local alias="$1" codename
  codename="$(curl -fsSL "https://deb.debian.org/debian/dists/${alias}/Release" 2>/dev/null \
    | sed -nE 's/^Codename:[[:space:]]*([^[:space:]]+).*/\1/p')" || return 1
  [[ -n "${codename}" ]] || return 1
  printf '%s\n' "${codename}"
}
# --

# Read a Debian sources API response on stdin and print the x.y.z QEMU versions
# shipped by the given suite codenames (args), newest first.
function _qemu_versions_in() {
  jq -r --args '
      ($ARGS.positional) as $cn
      | .versions[]?
      | select((.suites // []) | any(. as $s | $cn | index($s)))
      | .version' "$@" \
    | sed -nE 's/^[0-9]+:([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' \
    | sort -Vru
}
# --

# Return 0 if the given Debian codename ships the requested x.y.z QEMU version.
function _qemu_version_in() {
  local api="$1" ver="$2" codename="$3"
  echo "${api}" | jq -e --arg v "${ver}" --arg c "${codename}" '
      .versions[]?
      | select((.suites // []) | index($c))
      | select(.version | test("^[0-9]+:" + ($v | gsub("\\.";"\\.")) + "([-+~]|$)"))
    ' >/dev/null
}
# --

function list_available_versions() {
  local api stable testing
  stable="$(_debian_codename stable)" && testing="$(_debian_codename testing)" || {
    echo "ERROR: failed to resolve Debian stable/testing codenames." >&2
    return 1
  }
  api="$(curl -fsSL "${DEBIAN_QEMU_API}")" || {
    echo "ERROR: failed to query the Debian sources API (${DEBIAN_QEMU_API})." >&2
    return 1
  }
  echo "${api}" | _qemu_versions_in "${stable}" "${testing}"
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

  # Map the stable/testing aliases to codenames (the sources API only tags by
  # codename) and fetch the version list ONCE. Fail hard on any lookup/parse
  # error so a transient failure can't silently change which suite (and thus
  # which QEMU version) we build against.
  local stable testing api
  stable="$(_debian_codename stable)" && testing="$(_debian_codename testing)" || {
    echo "ERROR: failed to resolve Debian stable/testing codenames." >&2
    return 1
  }
  api="$(curl -fsSL "${DEBIAN_QEMU_API}")" || {
    echo "ERROR: failed to query the Debian sources API (${DEBIAN_QEMU_API})." >&2
    return 1
  }
  echo "${api}" | jq -e '.versions' >/dev/null 2>&1 || {
    echo "ERROR: unexpected response from the Debian sources API." >&2
    return 1
  }

  # 'latest' resolves to the newest version in stable/testing so the checks below
  # have a concrete target.
  if [[ "${version}" == "latest" ]]; then
    version="$(echo "${api}" | _qemu_versions_in "${stable}" "${testing}" | head -1)"
    [[ -n "${version}" ]] || {
      echo "ERROR: could not determine the latest qemu version from Debian." >&2
      return 1
    }
  fi

  # Choose the suite that actually ships the requested version: prefer stable,
  # else testing, else fail. Never fall back blindly.
  local suite=""
  if _qemu_version_in "${api}" "${version}" "${stable}"; then
    suite="stable"
  elif _qemu_version_in "${api}" "${version}" "${testing}"; then
    suite="testing"
  else
    echo "ERROR: qemu ${version} is not in Debian stable (${stable}) or testing (${testing})." >&2
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
