#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# The BlueZ sysext.
#
# BlueZ is the Linux Bluetooth userspace: bluetoothd plus the bluetoothctl /
# btmon / btmgmt tools. It has no upstream static or portable release, and it
# links glib, dbus and readline, so this extension bundles the binaries with
# their shared-library closure (including glibc + the dynamic loader) extracted
# from a Debian container. tools/flix.sh resolves the closure and patchelf's the
# binaries onto a private loader/rpath, isolating them from the host's libraries
# (same approach as qemu.sysext and tilde.sysext). Debian packages BlueZ, so the
# version parameter selects the Debian suite (stable/testing) that ships it.
#
# The kernel side is not part of this extension: Bluetooth modules have to match
# the running kernel exactly, so they belong in the Flatcar image rather than in
# a sysext. Flatcar images built after flatcar/scripts#4197 carry them.

RELOAD_SERVICES_ON_MERGE="true"

DEBIAN_BLUEZ_API="https://sources.debian.org/api/src/bluez/"

# A transient network hiccup should not fail a build; same retry policy the
# other recipes in this repo use (consul, haproxy, nomad, vault).
CURL_RETRY=(--retry-delay 1 --retry 60 --retry-connrefused
            --retry-max-time 60 --connect-timeout 20)

# Resolve a Debian suite alias (stable/testing) to its codename from the archive
# Release file, e.g. stable -> trixie. The sources API tags versions by codename
# only, so we need this mapping. Fails if the lookup can't be made.
function _debian_codename() {
  local alias="$1" codename
  codename="$(curl -fsSL "${CURL_RETRY[@]}" "https://deb.debian.org/debian/dists/${alias}/Release" 2>/dev/null \
    | sed -nE 's/^Codename:[[:space:]]*([^[:space:]]+).*/\1/p')" || return 1
  [[ -n "${codename}" ]] || return 1
  printf '%s\n' "${codename}"
}
# --

# Read a Debian sources API response on stdin and print the x.y BlueZ versions
# shipped by the given suite codenames (args), newest first.
function _bluez_versions_in() {
  jq -r --args '
      ($ARGS.positional) as $cn
      | .versions[]?
      | select((.suites // []) | any(. as $s | $cn | index($s)))
      | .version' "$@" \
    | sed -nE 's/^([0-9]+\.[0-9]+).*/\1/p' \
    | sort -Vru
}
# --

# Return 0 if the given Debian codename ships the requested x.y BlueZ version.
function _bluez_version_in() {
  local api="$1" ver="$2" codename="$3"
  echo "${api}" | jq -e --arg v "${ver}" --arg c "${codename}" '
      .versions[]?
      | select((.suites // []) | index($c))
      | select(.version | test("^" + ($v | gsub("\\.";"\\.")) + "([-.+~]|$)"))
    ' >/dev/null
}
# --

function list_available_versions() {
  local api stable testing
  stable="$(_debian_codename stable)" && testing="$(_debian_codename testing)" || {
    echo "ERROR: failed to resolve Debian stable/testing codenames." >&2
    return 1
  }
  api="$(curl -fsSL "${CURL_RETRY[@]}" "${DEBIAN_BLUEZ_API}")" || {
    echo "ERROR: failed to query the Debian sources API (${DEBIAN_BLUEZ_API})." >&2
    return 1
  }
  echo "${api}" | _bluez_versions_in "${stable}" "${testing}"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch
  img_arch="$(arch_transform 'x86-64' 'amd64' "${arch}")"
  img_arch="$(arch_transform 'arm64' 'arm64' "${img_arch}")"

  # Map the stable/testing aliases to codenames (the sources API only tags by
  # codename) and fetch the version list ONCE. Fail hard on any lookup/parse
  # error so a transient failure can't silently change which suite (and thus
  # which BlueZ version) we build against.
  local stable testing api
  stable="$(_debian_codename stable)" && testing="$(_debian_codename testing)" || {
    echo "ERROR: failed to resolve Debian stable/testing codenames." >&2
    return 1
  }
  api="$(curl -fsSL "${CURL_RETRY[@]}" "${DEBIAN_BLUEZ_API}")" || {
    echo "ERROR: failed to query the Debian sources API (${DEBIAN_BLUEZ_API})." >&2
    return 1
  }
  echo "${api}" | jq -e '.versions' >/dev/null 2>&1 || {
    echo "ERROR: unexpected response from the Debian sources API." >&2
    return 1
  }

  # 'latest' resolves to the newest version in stable/testing so the checks below
  # have a concrete target.
  if [[ "${version}" == "latest" ]]; then
    version="$(echo "${api}" | _bluez_versions_in "${stable}" "${testing}" | head -1)"
    [[ -n "${version}" ]] || {
      echo "ERROR: could not determine the latest bluez version from Debian." >&2
      return 1
    }
  fi

  # Choose the suite that actually ships the requested version: prefer stable,
  # else testing, else fail. Never fall back blindly.
  local suite=""
  if _bluez_version_in "${api}" "${version}" "${stable}"; then
    suite="stable"
  elif _bluez_version_in "${api}" "${version}" "${testing}"; then
    suite="testing"
  else
    echo "ERROR: bluez ${version} is not in Debian stable (${stable}) or testing (${testing})." >&2
    return 1
  fi

  announce "Building bluez ${version} (Debian ${suite}) for ${arch}"

  # Build the sysext inside a Debian container of the chosen suite: install
  # BlueZ, verify bluetoothd actually matches the requested version (a moved
  # suite must not silently produce a different build), then hand the binaries
  # and the D-Bus policy to tools/flix.sh, which resolves the library closure
  # and patchelf's them onto a private loader/rpath.
  docker run --rm -i \
    -v "${scriptroot}/tools/":/tools \
    -v "${sysextroot}":/install_root \
    --platform "linux/${img_arch}" \
    --pull always \
    --network host \
    -e WANT_VERSION="${version}" \
    "docker.io/debian:${suite}-slim" bash -euc '
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -qq
      apt-get install -y -qq --no-install-recommends bluez patchelf >/dev/null

      # bluetoothd moved from /usr/lib to /usr/libexec across Debian releases.
      bluetoothd=""
      for c in /usr/libexec/bluetooth/bluetoothd /usr/lib/bluetooth/bluetoothd; do
        [ -x "${c}" ] && bluetoothd="${c}" && break
      done
      if [ -z "${bluetoothd}" ]; then
        echo "ERROR: bluetoothd not found in the bluez package." >&2
        exit 1
      fi

      got="$("${bluetoothd}" --version | sed -nE "s/^([0-9]+\.[0-9]+).*/\1/p" | head -1)"
      if [ "${got}" != "${WANT_VERSION}" ]; then
        echo "ERROR: requested bluez ${WANT_VERSION} but Debian installs ${got}." >&2
        exit 1
      fi

      # bluetoothd plus every CLI tool this suite's bluez package ships. Take
      # the list from the package rather than hardcoding it: the tool set drifts
      # across Debian releases (the legacy hciconfig/hcitool/... tools are
      # deprecated upstream and already gone from newer ones), and a hardcoded
      # subset silently drops tools that are still shipped -- hciattach in
      # particular, which is what attaches a UART controller.
      paths="${bluetoothd}"
      for b in $(dpkg -L bluez | sed -nE 's|^(/usr/s?bin/[^/]+)$|\1|p' | sort -u); do
        [ -f "${b}" ] && [ -x "${b}" ] && paths="${paths} ${b}"
      done

      # bluetoothd will not take its name on the system bus without this policy.
      dbus_conf=""
      for c in /usr/share/dbus-1/system.d/bluetooth.conf \
               /etc/dbus-1/system.d/bluetooth.conf; do
        [ -f "${c}" ] && dbus_conf="${c}" && break
      done
      if [ -z "${dbus_conf}" ]; then
        echo "ERROR: the bluez D-Bus policy file was not found." >&2
        exit 1
      fi
      # flix.sh only accepts the "source:target" form for paths outside /usr;
      # a path that is already under /usr must be passed as-is.
      case "${dbus_conf}" in
        /usr/*) paths="${paths} ${dbus_conf}" ;;
        *)      paths="${paths} ${dbus_conf}:/usr/share/dbus-1/system.d/bluetooth.conf" ;;
      esac

      cd /install_root
      /tools/flix.sh / bluez ${paths}

      # bluetoothd is looked up at a fixed path by our unit; normalise the
      # location so the unit does not have to care which Debian release we used.
      if [ "${bluetoothd}" != "/usr/libexec/bluetooth/bluetoothd" ]; then
        mkdir -p bluez/usr/libexec/bluetooth
        mv "bluez${bluetoothd}" bluez/usr/libexec/bluetooth/bluetoothd
      fi

      owner="$(stat -c "%u:%g" /install_root)"
      if [ "${owner}" != "$(id -u):$(id -g)" ]; then
        chown -R "${owner}" /install_root/bluez
      fi
    '

  # Merge rather than move: the bakery has already copied this extension's
  # static files/ tree into ${sysextroot}/usr before calling us.
  mkdir -p "${sysextroot}/usr"
  cp -a "${sysextroot}/bluez/usr/." "${sysextroot}/usr/"
  rm -rf "${sysextroot}/bluez"
}
# --
